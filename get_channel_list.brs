sub init()
    m.top.functionName = "getContent"
end sub

' **********************************************

sub getContent()
    ' Fetch feed URL(s) from registry (supports multiple M3U URLs)
    reg = CreateObject("roRegistrySection", "profile")
    
    if reg.Exists("feedUrls")
        m.global.feedUrls = reg.Read("feedUrls")
    else
        m.global.feedUrls = [] ' Default to an empty list if none exist
    end if
    
    if m.global.feedUrls.count() = 0
        m.global.feedUrls.Push("https://pastebin.com/raw/v0dE8SdX") ' Default to a single demo URL
    end if
    
    ' Create a port for communication
    m.port = CreateObject("roMessagePort")
    
    ' Initialize an empty list to store combined channel data
    m.channelList = []
    
    ' Fetch the M3U data for each URL in the feed list
    for each url in m.global.feedUrls
        fetchM3U(url)
    end for
end sub

' **********************************************

sub fetchM3U(url as String)
    ' Create an HTTP request for the M3U feed
    searchRequest = CreateObject("roUrlTransfer")
    searchRequest.setURL(url)
    searchRequest.EnableEncodings(true)
    
    ' Handle HTTPS connections
    httpsReg = CreateObject("roRegex", "^https:", "")
    if httpsReg.isMatch(url)
        searchRequest.SetCertificatesFile("common:/certs/ca-bundle.crt")
        searchRequest.AddHeader("X-Roku-Reserved-Dev-Id", "")
        searchRequest.InitClientCertificates()
    end if
    
    ' Start the request asynchronously
    searchRequest.SetMessagePort(m.port)
    searchRequest.AsyncGet()
    
    ' Wait for the response or timeout
    startTime = GetTickCount()
    timeout = 10000  ' Timeout set to 10 seconds (10000 ms)
    
    while true
        msg = wait(0, m.port)
        elapsedTime = GetTickCount() - startTime
        if elapsedTime > timeout
            print "Error: Timeout while fetching URL: " + url
            return
        end if

        if type(msg) = "roUrlEvent"
            if msg.isResponseReceived()
                if msg.getResponseCode() = 200
                    parseM3U(msg.getData())
                else
                    print "Error fetching M3U feed (Response code: " + str(msg.getResponseCode()) + "): " + url
                end if
            else
                print "Error fetching M3U feed (No response received): " + url
            end if
        end if
    end while
end sub

' **********************************************

sub parseM3U(data as String)
    ' Parse the M3U playlist and extract the channel details
    m.groupedChannels = {}  ' Clear previous groupings

    ' Split the data into lines
    lines = Split(data, Chr(10)) ' Split by line breaks
    
    inExtinf = false
    con = CreateObject("roSGNode", "ContentNode") ' Create root ContentNode
    
    ' Define regex patterns to parse the EXTINF metadata and the channel URLs
    reLineSplit = CreateObject("roRegex", "(?>\r\n|[\r\n])", "")
    reExtinf = CreateObject("roRegex", "(?i)^#EXTINF:\s*(\d+|-1|-0).*,\s*(.*)$", "") ' Regex to match EXTINF
    rePath = CreateObject("roRegex", "^([^#].*)$", "") ' Regex to match the actual media URL
    
    for each line in reLineSplit.Split(data)
        if inExtinf
            ' Match the URL
            maPath = rePath.Match(line)
            if maPath.Count() = 2
                item = con.CreateChild("ContentNode")
                item.url = maPath[1]
                item.title = title
                item.tvgLogo = tvgLogo
                inExtinf = false
            end if
        end if
        
        ' Match the EXTINF metadata (e.g., #EXTINF:-1 tvg-logo="logo.png" group-title="Sports", Channel Name)
        maExtinf = reExtinf.Match(line)
        if maExtinf.Count() = 3
            length = maExtinf[1].ToInt()
            if length < 0 then length = 0
            title = maExtinf[2]
            
            ' Look for group-title and tvg-logo
            groupTitle = ExtractGroupTitle(line)
            tvgLogo = ExtractTvgLogo(line)
            
            ' If group-title is found, create a group or update existing one
            group = GetGroup(groupTitle)
            
            inExtinf = true
        end if
    end for

    ' Pass the grouped channels to the UI
    m.top.content = con
end sub

' **********************************************

' Helper function to extract the group-title from EXTINF line
function ExtractGroupTitle(line as String) as String
    reGroupTitle = CreateObject("roRegex", "group-title\s*=\s*\"([^\"]+)\"", "")
    if reGroupTitle.isMatch(line)
        return reGroupTitle.Match(line)[1]
    else
        return "Unknown Group"
    end if
end function

' **********************************************

' Helper function to extract the tvg-logo from EXTINF line
function ExtractTvgLogo(line as String) as String
    reTvgLogo = CreateObject("roRegex", "tvg-logo\s*=\s*\"([^\"]+)\"", "")
    if reTvgLogo.isMatch(line)
        return reTvgLogo.Match(line)[1]
    else
        return ""
    end if
end function

' **********************************************

' Helper function to get or create a group node
function GetGroup(groupName as String) as Object
    group = invalid
    if m.groupedChannels.exists(groupName)
        group = m.groupedChannels[groupName]
    else
        group = CreateObject("roSGNode", "ContentNode")
        group.id = groupName
        group.contenttype = "SECTION"
        group.title = groupName
        m.groupedChannels[groupName] = group
        m.top.content.AppendChild(group)
    end if
    return group
end function
