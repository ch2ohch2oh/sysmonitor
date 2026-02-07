// Fetch latest release information from GitHub
async function fetchLatestRelease() {
    try {
        const response = await fetch('https://api.github.com/repos/ch2ohch2oh/sysmonitor/releases/latest');
        const data = await response.json();
        
        // Update version display
        const versionElement = document.getElementById('latest-version');
        if (data.tag_name) {
            versionElement.textContent = data.tag_name;
        } else {
            versionElement.textContent = 'v1.0.0';
        }
        
        // Update download button
        const downloadBtn = document.getElementById('download-btn');
        if (data.assets && data.assets.length > 0) {
            const zipAsset = data.assets.find(asset => asset.name.endsWith('.zip'));
            if (zipAsset) {
                downloadBtn.href = zipAsset.browser_download_url;
            } else {
                downloadBtn.href = data.assets[0].browser_download_url;
            }
        } else {
            downloadBtn.href = 'https://github.com/ch2ohch2oh/sysmonitor/releases/latest';
        }
    } catch (error) {
        console.error('Error fetching release info:', error);
        document.getElementById('latest-version').textContent = 'Latest';
        document.getElementById('download-btn').href = 'https://github.com/ch2ohch2oh/sysmonitor/releases/latest';
    }
}

// Fetch on page load
document.addEventListener('DOMContentLoaded', fetchLatestRelease);
