sub init()
    m.top.backgroundURI = "pkg:/images/background-controls.jpg"

    ' Initialize components
    m.save_feed_url = m.top.FindNode("save_feed_url")  ' Save URL to registry
    m.get_channel_list = m.top.FindNode("get_channel_list") ' Get and parse the feed URL
    m.get_channel_list.ObserveField("content", "SetContent") ' Is content parsed? If so, go to SetContent
    
    m.list = m.top.FindNode("list")
    m.list.ObserveField("itemSelected", "setChannel")

    m.video = m.top.FindNode("Video")
    m.video.ObserveField("state", "checkState")

    ' Check for saved feed URL
    m.global.feedUrls = LoadFeedUrls()
    m.currentFeedIndex = 0 ' Start with the first feed URL
    m.channelList = []
    
    ' Load channels for the current feed
    loadChannels()

    ' Show the dialog (keyboard prompt for URL input)
    showdialog()
End sub

' Function to handle key events
function onKeyEvent(key as String, press as Boolean) as Boolean
    result = false

    if press
        if key = "right"
            m.list.SetFocus(false)
            m.top.SetFocus(true)
            m.video.translation = [0, 0]
            m.video.width = 0
            m.video.height = 0
            result = true
        else if key = "left"
            m.list.SetFocus(true)
            m.video.translation = [800, 100]
            m.video.width = 960
            m.video.height = 540
            result = true
        else if key = "back"
            m.list.SetFocus(true)
            m.video.translation = [800, 100]
            m.video.width = 960
            m.video.height = 540
            result = true
        else if key = "options"
            showdialog()
            result = true
        end if
    end if

    return result
end function

' Check the state of the video player
sub checkState()
    state = m.video.state
    if state = "error"
        m.top.dialog = CreateObject("roSGNode", "Dialog")
        m.top.dialog.title = "Error: " + str(m.video.errorCode)
        m.top.dialog.message = m.video.errorMsg
    end if
end sub

' Set content for the channel list
sub SetContent()
    m.list.content = m.channelList
    m.list.SetFocus(true)
end sub

' Set the selected channel for playback
sub setChannel()
    if m.list.content.getChild(0).getChild(0) = invalid
        content = m.list.content.getChild(m.list.itemSelected)
    else
        itemSelected = m.list.itemSelected
        for i = 0 to m.list.currFocusSection - 1
            itemSelected = itemSelected - m.list.content.getChild(i).getChildCount()
        end for
        content = m.list.content.getChild(m.list.currFocusSection).getChild(itemSelected)
    end if

    content.streamFormat = "hls"

    if m.video.content <> invalid and m.video.content.url = content.url return

    content.HttpSendClientCertificates = true
    content.HttpCertificatesFile = "common:/certs/ca-bundle.crt"
    m.video.EnableCookies()
    m.video.SetCertificatesFile("common:/certs/ca-bundle.crt")
    m.video.InitClientCertificates()

    m.video.content = content

    m.top.backgroundURI = "pkg:/images/rsgde_bg_hd.jpg"
    m.video.trickplaybarvisibilityauto = false

    m.video.control = "play"

    ' If EPG URL is available, fetch and display EPG
    if content.epgUrl <> ""
        fetchEPG(content.epgUrl)
    else
        showEPG("No EPG data available.")
    end if
end sub

' Fetch EPG data for the selected channel
sub fetchEPG(epgUrl as String)
    port = CreateObject("roMessagePort")
    req = CreateObject("roUrlTransfer")
    req.SetPort(port)
    req.SetUrl(epgUrl)
    req.AsyncGet()

    msg = Wait(0, port)
    if msg.isType("roUrlEvent")
        epgData = msg.GetData()  ' Get raw EPG data
        parsedEPG = ParseEPGData(epgData)  ' Parse the EPG XML data
        showEPG(parsedEPG)  ' Show the parsed EPG
    end if
end sub

' Parse the EPG XML data to extract program information
function ParseEPGData(epgData as String) as Object
    programs = []  ' List to hold parsed program details
    xmlParser = CreateObject("roXmlParser")
    result = xmlParser.Parse(epgData)

    if result <> invalid
        ' Assuming XML structure like <programme start="20231103080000" stop="20231103090000">
        for each program in result.GetElements("programme")
            programDetails = {}
            programDetails.title = program.GetChild("title").GetText()
            programDetails.start = program.GetChild("start").GetText()
            programDetails.stop = program.GetChild("stop").GetText()
            programs.Push(programDetails)
        end for
    end if

    return programs
end function

' Display the parsed EPG data in the UI
sub showEPG(epgData as Object)
    ' Assuming there's a node to display the EPG guide
    epgList = m.top.FindNode("epgList")
    
    if epgList <> invalid
        epgList.content = epgData  ' Set the EPG data content to the UI node
        epgList.SetFocus(true)
        epgList.visible = true  ' Show the EPG list
    end if
end sub

' Load saved feed URLs from the registry
function LoadFeedUrls() as Object
    reg = CreateObject("roRegistrySection", "profile")
    if reg.Exists("feedUrls")
        return reg.Read("feedUrls")
    else
        return []
    end if
end function

' Show the URL input dialog
sub showdialog()
    PRINT ">>>  ENTERING KEYBOARD <<<"

    keyboarddialog = createObject("roSGNode", "KeyboardDialog")
    keyboarddialog.backgroundUri = "pkg:/images/rsgde_bg_hd.jpg"
    keyboarddialog.title = "Enter .m3u URL"

    keyboarddialog.buttons = ["OK", "Set back to Demo", "Save"]
    keyboarddialog.optionsDialog = true

    m.top.dialog = keyboarddialog
    m.top.dialog.text = m.global.feedurl
    m.top.dialog.keyboard.textEditBox.cursorPosition = len(m.global.feedurl)
    m.top.dialog.keyboard.textEditBox.maxTextLength = 300

    KeyboardDialog.observeFieldScoped("buttonSelected", "onKeyPress")
end sub

' Handle the keyboard dialog button press
sub onKeyPress()
    if m.top.dialog.buttonSelected = 0 ' OK
        url = m.top.dialog.text
        m.global.feedurl = url
        m.save_feed_url.control = "RUN"
        m.top.dialog.close = true
        m.get_channel_list.control = "RUN"
    else if m.top.dialog.buttonSelected = 1 ' Set back to Demo
        m.top.dialog.text = "https://pastebin.com/raw/v0dE8SdX"
    else if m.top.dialog.buttonSelected = 2 ' Save
        m.global.feedurl = m.top.dialog.text
        m.save_feed_url.control = "RUN"
    end if
end sub
