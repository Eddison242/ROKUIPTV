' ********** Copyright 2016 Roku Corp.  All Rights Reserved. ********** 

sub Main()
    ' Load M3U URLs from the manifest
    m3uUrls = GetM3UUrlsFromManifest() ' Function to parse the M3U URLs from the manifest
    epgRefreshInterval = 3600 ' Default refresh interval for EPG (1 hour)
    
    ' Initialize screen and messaging
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    m.global = screen.getGlobalNode()

    ' Initial playlist URL (can be set to the first URL in the list for testing)
    m.global.addFields({feedurl: m3uUrls[0]})
    scene = screen.CreateScene("MainScene")
    screen.show()

    ' Process playlists and EPG data
    ProcessPlaylistsAndEPG(m3uUrls)

    ' Main loop for screen events
    while(true)
        msg = wait(0, m.port)
        msgType = type(msg)
        print "msgTYPE >>>>>>>>"; type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if
    end while
end sub

' Function to parse the M3U URLs from the manifest
function GetM3UUrlsFromManifest() as Object
    reg = CreateObject("roRegistrySection", "profile")
    if reg.Exists("m3u_urls")
        m3uUrlsString = reg.Read("m3u_urls") ' Get the M3U URLs from the manifest
        m3uUrls = Split(m3uUrlsString, ",") ' Split by commas to create an array of URLs
        return m3uUrls
    else
        ' Default fallback M3U URL if none is specified
        return ["https://pastebin.com/raw/v0dE8SdX"]
    end if
end function

' Function to process playlists and handle EPG extraction
function ProcessPlaylistsAndEPG(m3uUrls as Object)
    for each m3uUrl in m3uUrls
        channels = ParseM3U(m3uUrl) ' Parse the M3U playlist
        for each channel in channels
            if channel.epgUrl <> "" then
                ' If an EPG URL exists, fetch and refresh EPG data
                print "Fetching EPG data from: "; channel.epgUrl
                FetchEPGData(channel.epgUrl)
            else
                print "No EPG URL found for channel: "; channel.name
            end if
        end for
    end for
end function

' Function to parse M3U file for channels and their EPG URLs
function ParseM3U(m3uUrl as String) as Object
    port = CreateObject("roMessagePort")
    req = CreateObject("roUrlTransfer")
    req.SetPort(port)
    req.SetUrl(m3uUrl)
    req.AsyncGet()
    
    msg = Wait(0, port)
    if msg.isType("roUrlEvent")
        m3uData = msg.GetData() ' Raw M3U data (string)
        
        ' Parse M3U data for channel info and EPG URL
        m3uLines = Split(m3uData, Chr(10)) ' Split by line
        channels = []
        
        for each line in m3uLines
            ' Look for channel lines that contain information, e.g., starting with #EXTINF
            if InStr(line, "#EXTINF:")
                channel = {}
                ' Extract channel name, description, or other info here
                channel.name = line
                
                ' Check for EPG URL in the line
                if InStr(line, "epg_url=") ' Assuming the EPG URL is passed as part of the channel metadata
                    channel.epgUrl = ExtractEPGUrl(line)
                else
                    channel.epgUrl = "" ' No EPG URL found
                end if
                
                ' Add the channel to the list
                channels.Push(channel)
            end if
        end for
        
        ' Return the list of channels (including EPG URLs if available)
        return channels
    end if
end function

' Helper function to extract EPG URL from metadata
function ExtractEPGUrl(line as String) as String
    ' Example: extracting "epg_url=http://example.com/epg.xml"
    epgUrlPattern = "epg_url="
    startPos = InStr(line, epgUrlPattern)
    if startPos > 0
        epgUrl = Mid(line, startPos + Len(epgUrlPattern), Len(line) - startPos)
        return epgUrl
    else
        return "" ' No EPG URL found
    end if
end function

' Function to fetch and process EPG data (XML or JSON)
function FetchEPGData(epgUrl as String)
    port = CreateObject("roMessagePort")
    req = CreateObject("roUrlTransfer")
    req.SetPort(port)
    req.SetUrl(epgUrl)
    req.AsyncGet()
    
    msg = Wait(0, port)
    if msg.isType("roUrlEvent")
        epgData = msg.GetData() ' Raw EPG data (either XML or JSON)
        
        ' Determine the data format and parse accordingly
        if IsXML(epgData)
            ParseEPGXML(epgData)
        else if IsJSON(epgData)
            ParseEPGJSON(epgData)
        else
            print "Unsupported EPG format for URL: "; epgUrl
        end if
    end if
end function

' Function to determine if data is in XML format
function IsXML(data as String) as Boolean
    return InStr(data, "<?xml") > 0
end function

' Function to determine if data is in JSON format
function IsJSON(data as String) as Boolean
    return InStr(data, "{") > 0 and InStr(data, "}") > 0
end function

' Function to parse EPG data in XML format
function ParseEPGXML(epgData as String)
    ' Parse the EPG XML using roXMLParser
    parser = CreateObject("roXMLParser")
    result = parser.Parse(epgData)
    
    ' Assuming EPG XML has a structure like:
    ' <guide>
    '     <channel>
    '         <name>Channel 1</name>
    '         <program start="2024-11-05T12:00:00" end="2024-11-05T13:00:00">
    '             <title>Program Title</title>
    '             <desc>Program description</desc>
    '         </program>
    '     </channel>
    ' </guide>
    
    ' Iterate over channels and programs
    channels = result.GetChildElements()
    for each channel in channels
        channelName = channel.GetChildElement("name").GetText()
        programs = channel.GetChildElements()
        for each program in programs
            startTime = program.GetAttribute("start")
            endTime = program.GetAttribute("end")
            title = program.GetChildElement("title").GetText()
            description = program.GetChildElement("desc").GetText()
            
            ' Print program details
            print "EPG - Channel: "; channelName; ", Title: "; title; ", Time: "; startTime; " - "; endTime
        end for
    end for
end function

' Function to parse EPG data in JSON format
function ParseEPGJSON(epgData as String)
    ' Parse the EPG JSON using roJSON
    json = CreateObject("roJSON")
    epg = json.Parse(epgData)
    
    ' Assuming EPG JSON has a structure like:
    ' {
    '     "guide": [
    '         {
    '             "channel": "Channel 1",
    '             "programs": [
    '                 {
    '                     "start": "2024-11-05T12:00:00",
    '                     "end": "2024-11-05T13:00:00",
    '                     "title": "Program Title",
    '                     "description": "Program description"
    '                 }
    '             ]
    '         }
    '     ]
    ' }
    
    guide = epg["guide"]
    for each channel in guide
        channelName = channel["channel"]
        programs = channel["programs"]
        for each program in programs
            startTime = program["start"]
            endTime = program["end"]
            title = program["title"]
            description = program["description"]
            
            ' Print program details
            print "EPG - Channel: "; channelName; ", Title: "; title; ", Time: "; startTime; " - "; endTime
        end for
    end for
end function
