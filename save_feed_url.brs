sub init()
    m.top.functionName = "saveurl"
end sub

' ****************************************

sub saveFeedUrl()
    reg = CreateObject("roRegistrySection", "profile")

    ' Ensure that we have a list of feed URLs
    if m.global.feedUrls = invalid
        m.global.feedUrls = [] ' Initialize the list if it doesn't exist
    end if

    ' Get the URL from the TextField input
    url = m.top.FindNode("urlTextField").text

    ' Validate that the URL is not empty
    if url <> "" and not FeedUrlExists(url)
        ' Add the new feed URL to the list
        m.global.feedUrls.Push(url)

        ' Save the list of feed URLs to the registry
        reg.Write("feedUrls", m.global.feedUrls)
        reg.Flush()

        ' Optionally, save the primary feed URL separately (if needed)
        m.global.feedurl = url
        reg.Write("primaryfeed", m.global.feedurl)
        reg.Flush()

        ' Notify user
        showDialog("Feed URL saved successfully!")
    else if url = ""
        showDialog("Please enter a valid URL.")
    else
        showDialog("This URL is already saved.")
    end if
end sub

' ****************************************

' Check if the feed URL already exists in the list
function FeedUrlExists(url as String) as Boolean
    for each feedUrl in m.global.feedUrls
        if feedUrl = url
            return true
        end if
    end for
    return false
end function

' ****************************************

' Cancel the current operation (close the dialog)
sub cancelFeedUrl()
    ' Hide the save feed URL dialog
    m.top.visible = false
end sub

' ****************************************

' Set the feed URL back to the demo URL (e.g., to the default feed)
sub setBackToDemo()
    demoUrl = "https://pastebin.com/raw/v0dE8SdX"
    m.global.feedurl = demoUrl
    m.global.feedUrls = [demoUrl] ' Replace the list with just the demo URL
    reg = CreateObject("roRegistrySection", "profile")
    reg.Write("feedUrls", m.global.feedUrls)
    reg.Flush()
    reg.Write("primaryfeed", demoUrl)
    reg.Flush()

    ' Notify user
    showDialog("Feed URL reset to demo.")
end sub

' ****************************************

' Function to display a dialog with a message
sub showDialog(message as String)
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = "Info"
    dialog.message = message
    m.top.dialog = dialog
end sub
