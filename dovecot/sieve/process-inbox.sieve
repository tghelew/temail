require ["include", "fileinto", "imap4flags"];

# rule:[Move Spam to Junk Folder]
if header :is "X-Spam" "yes"
{
    fileinto "Junk";
    addflag "\\Seen";
    stop;
}

include :global "report-ham";
