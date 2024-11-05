sub init()
    m.top.functionName = "saveurl"
end sub

' ****************************************

sub saveurl()
    reg = CreateObject("roRegistrySection", "profile")

    ' Ensure that we have a list of feed URLs
    if m.global.feedUrls = invalid
        m.global.feedUrls = [] ' Initialize the list if it doesn't exist
    end if
    
    ' Add the new feed URL to the list if it's not already present
    if not FeedUrlExists(m.global.feedurl)
        m.global.feedUrls.Push(m.global.feedurl)
    end if

    ' Save the list of feed URLs to the registry
    reg.Write("feedUrls", m.global.feedUrls)
    reg.Flush()

    ' Optionally, save the primary feed URL separately (if needed)
    reg.Write("primaryfeed", m.global.feedurl)
    reg.Flush()  
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
