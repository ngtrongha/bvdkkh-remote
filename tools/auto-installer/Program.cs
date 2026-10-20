// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà
// Description: Trình cài đặt tự động (GUI + Silent Bootstrapper) cho BVĐKKH - Remote
//              Tự động nhận diện Windows (Win7/8 vs Win10/11, x64/x86/ARM64),
//              ưu tiên lấy file cài từ máy chủ nội bộ LAN (\\172.16.2.9\chuongtrinhtest\_RushDesk),
//              tự động xác thực tài khoản chia sẻ nếu cần, và tự động dự phòng tải từ GitHub Releases.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Net;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

namespace BVDKKH.Remote.AutoInstaller
{
    static class Program
    {
        // 1. Cấu hình máy chủ chia sẻ nội bộ mạng LAN bệnh viện
        public const string DEFAULT_LAN_SHARE = @"\\172.16.2.9\chuongtrinhtest\_RushDesk";
        public static string LanSharePath = DEFAULT_LAN_SHARE;
        public static string LanShareUsername = "tiepdon"; // Tài khoản chia sẻ nội bộ BVĐKKH
        public static string LanSharePassword = "tiepdon";

        // 2. Cấu hình dự phòng qua GitHub Releases (khi ngoài mạng bệnh viện hoặc không vào được share)
        private const string GITHUB_API_URL = "https://api.github.com/repos/ngtrongha/bvdkkh-remote-release/releases/latest";
        private const string GITHUB_LATEST_WEB_URL = "https://github.com/ngtrongha/bvdkkh-remote-release/releases/latest";
        private const string GITHUB_EXPANDED_ASSETS_URL = "https://github.com/ngtrongha/bvdkkh-remote-release/releases/expanded_assets/";
        private const string LOG_FILE = "bvdkkh_installer.log";

        [DllImport("kernel32.dll")]
        private static extern bool AttachConsole(int dwProcessId);
        private const int ATTACH_PARENT_PROCESS = -1;

        [DllImport("kernel32.dll")]
        private static extern void GetNativeSystemInfo(ref SYSTEM_INFO lpSystemInfo);

        [StructLayout(LayoutKind.Sequential)]
        private struct SYSTEM_INFO
        {
            public ushort wProcessorArchitecture;
            public ushort wReserved;
            public uint dwPageSize;
            public IntPtr lpMinimumApplicationAddress;
            public IntPtr lpMaximumApplicationAddress;
            public IntPtr dwActiveProcessorMask;
            public uint dwNumberOfProcessors;
            public uint dwProcessorType;
            public uint dwAllocationGranularity;
            public ushort wProcessorLevel;
            public ushort wProcessorRevision;
        }

        private const ushort PROCESSOR_ARCHITECTURE_INTEL = 0;
        private const ushort PROCESSOR_ARCHITECTURE_AMD64 = 9;
        private const ushort PROCESSOR_ARCHITECTURE_ARM64 = 12;

        // P/Invoke kết nối thư mục mạng có xác thực mật khẩu qua Windows Networking (mpr.dll)
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
        public class NETRESOURCE
        {
            public uint dwScope = 2; // RESOURCE_GLOBALNET
            public uint dwType = 1;  // RESOURCETYPE_DISK
            public uint dwDisplayType = 3; // RESOURCEDISPLAYTYPE_SHARE
            public uint dwUsage = 1; // RESOURCEUSAGE_CONNECTABLE
            public string lpLocalName = null;
            public string lpRemoteName;
            public string lpComment = null;
            public string lpProvider = null;
        }

        [DllImport("mpr.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern int WNetAddConnection2(NETRESOURCE lpNetResource, string lpPassword, string lpUsername, int dwFlags);

        [DllImport("shell32.dll")]
        private static extern void SHChangeNotify(int wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);

        [STAThread]
        static int Main(string[] args)
        {
            ConfigureSecurityProtocol();

            bool isSilent = false;
            bool isCheckOnly = false;

            foreach (var arg in args)
            {
                string a = (arg ?? "").Trim();
                string lower = a.ToLowerInvariant();
                if (lower == "/s" || lower == "-s" || lower == "/silent" || lower == "--silent" || lower == "/quiet" || lower == "/q")
                {
                    isSilent = true;
                }
                else if (lower == "--check" || lower == "/check" || lower == "--test" || lower == "/test")
                {
                    isCheckOnly = true;
                }
                else if (lower.StartsWith("/user:") || lower.StartsWith("--user:"))
                {
                    LanShareUsername = a.Substring(a.IndexOf(':') + 1).Trim();
                }
                else if (lower.StartsWith("/pass:") || lower.StartsWith("--pass:") || lower.StartsWith("/password:"))
                {
                    LanSharePassword = a.Substring(a.IndexOf(':') + 1).Trim();
                }
                else if (lower.StartsWith("/share:") || lower.StartsWith("--share:"))
                {
                    LanSharePath = a.Substring(a.IndexOf(':') + 1).Trim();
                }
            }

            // 1. Kiểm tra quyền Quản trị viên (UAC) nếu cần cài đặt
            if (!isCheckOnly && !IsAdministrator())
            {
                try
                {
                    string exePath = Process.GetCurrentProcess().MainModule.FileName;
                    var psi = new ProcessStartInfo
                    {
                        FileName = exePath,
                        Arguments = string.Join(" ", args),
                        UseShellExecute = true,
                        Verb = "runas"
                    };
                    var proc = Process.Start(psi);
                    if (proc != null)
                    {
                        proc.WaitForExit();
                        return proc.ExitCode;
                    }
                    return 0;
                }
                catch
                {
                    MessageBox.Show("Trình cài đặt yêu cầu quyền Quản trị viên (Administrator) để cập nhật phần mềm và khởi động dịch vụ hệ thống.\n\nVui lòng nhấn chuột phải vào tập tin cài đặt và chọn 'Run as administrator'.", "Yêu cầu quyền Administrator", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    return 1;
                }
            }

            // 2. Chế độ kiểm tra (CLI / Check only)
            if (isCheckOnly)
            {
                AttachConsole(ATTACH_PARENT_PROCESS);
                try
                {
                    var stdOut = new StreamWriter(Console.OpenStandardOutput()) { AutoFlush = true };
                    Console.SetOut(stdOut);
                }
                catch { }

                var info = DetectEnvironment();
                Console.WriteLine("=================================================");
                Console.WriteLine("BVĐKKH - Remote Auto Installer | Thông tin thiết bị");
                Console.WriteLine("=================================================");
                Console.WriteLine("Hệ điều hành: " + info.OsName + " (" + info.Arch + ")");
                Console.WriteLine("Đường dẫn share LAN mặc định: " + LanSharePath);

                string lanFile = null;
                if (ConnectLanShare(LanSharePath, LanShareUsername, LanSharePassword))
                {
                    lanFile = ResolveLanInstallerFile(info, LanSharePath);
                }

                if (!string.IsNullOrEmpty(lanFile))
                {
                    Console.WriteLine("Trạng thái nguồn: KẾT NỐI MÁY CHỦ NỘI BỘ LAN THÀNH CÔNG");
                    Console.WriteLine("Tập tin cài đặt:  " + Path.GetFileName(lanFile));
                    Console.WriteLine("Đường dẫn tập tin:" + lanFile);
                }
                else
                {
                    Console.WriteLine("Trạng thái nguồn: Không tìm thấy gói LAN, chuyển dự phòng GitHub");
                    var rel = FetchLatestRelease();
                    var asset = ResolveMatchingAsset(info, rel);
                    Console.WriteLine("Phiên bản GitHub: " + rel.TagName);
                    Console.WriteLine("Gói tải:         " + asset.Key);
                    Console.WriteLine("Link:            " + asset.Value);
                }
                return 0;
            }

            // 3. Chế độ cài đặt ngầm hoàn toàn (Silent Mode - No UI)
            if (isSilent)
            {
                return RunSilentBackgroundInstall();
            }

            // 4. Chế độ giao diện đồ họa trực quan (Modern GUI Mode)
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            var mainForm = new ModernInstallerForm();
            Application.Run(mainForm);
            return mainForm.ExitCode;
        }

        public static bool IsAdministrator()
        {
            try
            {
                var identity = WindowsIdentity.GetCurrent();
                var principal = new WindowsPrincipal(identity);
                return principal.IsInRole(WindowsBuiltInRole.Administrator);
            }
            catch
            {
                return false;
            }
        }

        public static void ConfigureSecurityProtocol()
        {
            try
            {
                ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072 | (SecurityProtocolType)768 | SecurityProtocolType.Tls;
                ServicePointManager.ServerCertificateValidationCallback = (sender, cert, chain, errors) => true;
            }
            catch { }
        }

        public class DeviceInfo
        {
            public bool IsWin10OrLater;
            public string Arch;
            public string OsName;
        }

        public static DeviceInfo DetectEnvironment()
        {
            var info = new DeviceInfo();
            try
            {
                object regMajor = Registry.GetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion", "CurrentMajorVersionNumber", null);
                if (regMajor != null && Convert.ToInt32(regMajor) >= 10)
                {
                    info.IsWin10OrLater = true;
                }
                else
                {
                    info.IsWin10OrLater = Environment.OSVersion.Version.Major >= 10;
                }
            }
            catch
            {
                info.IsWin10OrLater = Environment.OSVersion.Version.Major >= 10;
            }

            info.OsName = info.IsWin10OrLater ? "Windows 10/11" : "Windows 7/8 (LTS)";

            try
            {
                var sysInfo = new SYSTEM_INFO();
                GetNativeSystemInfo(ref sysInfo);
                switch (sysInfo.wProcessorArchitecture)
                {
                    case PROCESSOR_ARCHITECTURE_AMD64:
                        info.Arch = "x64";
                        break;
                    case PROCESSOR_ARCHITECTURE_ARM64:
                        info.Arch = "ARM64";
                        break;
                    case PROCESSOR_ARCHITECTURE_INTEL:
                        info.Arch = "x86";
                        break;
                    default:
                        info.Arch = Environment.Is64BitOperatingSystem ? "x64" : "x86";
                        break;
                }
            }
            catch
            {
                info.Arch = Environment.Is64BitOperatingSystem ? "x64" : "x86";
            }

            return info;
        }

        public static bool ConnectLanShare(string remotePath, string username, string password)
        {
            try
            {
                if (Directory.Exists(remotePath)) return true;
            }
            catch { }

            if (string.IsNullOrEmpty(remotePath)) return false;

            try
            {
                var nr = new NETRESOURCE
                {
                    lpRemoteName = remotePath
                };
                string u = string.IsNullOrEmpty(username) ? null : username;
                string p = string.IsNullOrEmpty(password) ? null : password;
                int ret = WNetAddConnection2(nr, p, u, 0);
                // 0: NO_ERROR, 1219: ERROR_SESSION_CREDENTIAL_CONFLICT, 85: ERROR_ALREADY_ASSIGNED
                if (ret == 0 || ret == 1219 || ret == 85)
                {
                    return Directory.Exists(remotePath);
                }
            }
            catch { }

            return false;
        }

        public static string ResolveLanInstallerFile(DeviceInfo info, string sharePath)
        {
            try
            {
                if (!Directory.Exists(sharePath)) return null;

                var files = Directory.GetFiles(sharePath, "*.exe", SearchOption.TopDirectoryOnly);
                var candidates = new List<string>();

                foreach (var file in files)
                {
                    string name = Path.GetFileName(file).ToLowerInvariant();
                    if (name.Contains("autoinstall") || name.Contains("setup") || !name.Contains("rustdesk"))
                        continue;

                    if (info.IsWin10OrLater)
                    {
                        // Win10/11: Ưu tiên gói win10, hoặc x86_64 không chứa win7
                        if (name.Contains("win10") || (name.Contains("x86_64") && !name.Contains("win7")))
                        {
                            candidates.Add(file);
                        }
                    }
                    else
                    {
                        // Win7/8: Ưu tiên gói win7 hoặc sciter
                        if (name.Contains("win7") || name.Contains("sciter") || name.Contains("x86"))
                        {
                            candidates.Add(file);
                        }
                    }
                }

                if (candidates.Count == 0) return null;

                // Sắp xếp tìm bản mới nhất: ưu tiên version cao nhất trong tên file, sau đó đến ngày sửa đổi
                candidates.Sort((a, b) =>
                {
                    Version vA = ExtractVersion(Path.GetFileName(a));
                    Version vB = ExtractVersion(Path.GetFileName(b));
                    int cmp = vB.CompareTo(vA);
                    if (cmp != 0) return cmp;
                    return File.GetLastWriteTime(b).CompareTo(File.GetLastWriteTime(a));
                });

                return candidates[0];
            }
            catch
            {
                return null;
            }
        }

        public static Version ExtractVersion(string fileName)
        {
            var m = Regex.Match(fileName ?? "", @"(\d+)\.(\d+)\.(\d+)(?:\.(\d+))?");
            if (m.Success)
            {
                try
                {
                    return new Version(m.Value);
                }
                catch { }
            }
            return new Version(0, 0, 0);
        }

        public static void CopyFileWithProgress(string sourcePath, string destPath, Action<long, long> onProgress)
        {
            const int bufferSize = 65536; // 64 KB
            byte[] buffer = new byte[bufferSize];

            using (var src = new FileStream(sourcePath, FileMode.Open, FileAccess.Read, FileShare.Read, bufferSize))
            using (var dst = new FileStream(destPath, FileMode.Create, FileAccess.Write, FileShare.None, bufferSize))
            {
                long totalBytes = src.Length;
                long totalRead = 0;
                int bytesRead;

                while ((bytesRead = src.Read(buffer, 0, buffer.Length)) > 0)
                {
                    dst.Write(buffer, 0, bytesRead);
                    totalRead += bytesRead;
                    if (onProgress != null)
                    {
                        onProgress(totalRead, totalBytes);
                    }
                }
            }
        }

        public class ReleaseInfo
        {
            public string TagName;
            public List<KeyValuePair<string, string>> Assets = new List<KeyValuePair<string, string>>();
        }

        public static ReleaseInfo FetchLatestRelease()
        {
            var info = new ReleaseInfo();

            // 1. Thử qua GitHub API (lấy JSON đầy đủ danh sách assets)
            try
            {
                using (var client = new WebClient())
                {
                    client.Encoding = Encoding.UTF8;
                    client.Headers.Add("User-Agent", "BVDKKH-Remote-Installer/1.0");
                    string json = client.DownloadString(GITHUB_API_URL);
                    if (!string.IsNullOrEmpty(json))
                    {
                        var matchTag = Regex.Match(json, "\"tag_name\"\\s*:\\s*\"([^\"]+)\"");
                        if (matchTag.Success) info.TagName = matchTag.Groups[1].Value.Trim();

                        var matches = Regex.Matches(json, "\"name\"\\s*:\\s*\"([^\"]+)\"[^\\}]*?\"browser_download_url\"\\s*:\\s*\"([^\"]+)\"");
                        foreach (Match m in matches)
                        {
                            if (m.Success && m.Groups.Count >= 3)
                            {
                                info.Assets.Add(new KeyValuePair<string, string>(m.Groups[1].Value, m.Groups[2].Value));
                            }
                        }
                    }
                }
            }
            catch { }

            if (!string.IsNullOrEmpty(info.TagName) && info.Assets.Count > 0)
                return info;

            // 2. Dự phòng: Truy vấn HTTP 302 Redirect từ GitHub Web (bỏ qua triệt để giới hạn 60 req/h của GitHub API)
            if (string.IsNullOrEmpty(info.TagName))
            {
                try
                {
                    var req = (HttpWebRequest)WebRequest.Create(GITHUB_LATEST_WEB_URL);
                    req.Method = "HEAD";
                    req.AllowAutoRedirect = false;
                    req.UserAgent = "Mozilla/5.0";
                    req.Timeout = 6000;
                    using (var resp = (HttpWebResponse)req.GetResponse())
                    {
                        string loc = resp.GetResponseHeader("Location");
                        if (!string.IsNullOrEmpty(loc))
                        {
                            var m = Regex.Match(loc, @"releases/tag/([^/?#]+)");
                            if (m.Success) info.TagName = m.Groups[1].Value.Trim();
                        }
                    }
                }
                catch (WebException wex)
                {
                    var resp = wex.Response as HttpWebResponse;
                    if (resp != null)
                    {
                        string loc = resp.GetResponseHeader("Location");
                        if (!string.IsNullOrEmpty(loc))
                        {
                            var m = Regex.Match(loc, @"releases/tag/([^/?#]+)");
                            if (m.Success) info.TagName = m.Groups[1].Value.Trim();
                        }
                    }
                }
                catch { }
            }

            // 3. Nếu tìm được tag từ redirect, tải danh sách file thực tế từ expanded_assets/{tag}
            if (!string.IsNullOrEmpty(info.TagName) && info.Assets.Count == 0)
            {
                try
                {
                    using (var client = new WebClient())
                    {
                        client.Encoding = Encoding.UTF8;
                        client.Headers.Add("User-Agent", "Mozilla/5.0");
                        string html = client.DownloadString(GITHUB_EXPANDED_ASSETS_URL + info.TagName);
                        var matches = Regex.Matches(html, "\"(/ngtrongha/bvdkkh-remote-release/releases/download/[^\"]+/rustdesk-[^\"]+\\.exe)\"");
                        foreach (Match m in matches)
                        {
                            if (m.Success && m.Groups.Count >= 2)
                            {
                                string href = m.Groups[1].Value;
                                string fileName = Path.GetFileName(href);
                                info.Assets.Add(new KeyValuePair<string, string>(fileName, "https://github.com" + href));
                            }
                        }
                    }
                }
                catch { }
            }

            // Trường hợp offline hoàn toàn hoặc không thể truy cập internet
            if (string.IsNullOrEmpty(info.TagName))
            {
                info.TagName = "v1.5.17";
            }

            return info;
        }

        public static KeyValuePair<string, string> ResolveMatchingAsset(DeviceInfo info, ReleaseInfo release)
        {
            if (release != null && release.Assets != null && release.Assets.Count > 0)
            {
                foreach (var asset in release.Assets)
                {
                    string name = asset.Key;
                    string lower = name.ToLowerInvariant();

                    if (!lower.EndsWith(".exe") || lower.EndsWith(".apk") || lower.Contains("setup"))
                        continue;

                    if (info.Arch == "ARM64" && lower.Contains("aarch64"))
                        return asset;

                    if (info.Arch == "x86" && lower.Contains("x86-sciter"))
                        return asset;

                    if (info.IsWin10OrLater && info.Arch == "x64")
                    {
                        if (lower.Contains("x86_64") && !lower.Contains("win7"))
                            return asset;
                    }
                    else if (!info.IsWin10OrLater)
                    {
                        if (info.Arch == "x64" && lower.Contains("win7") && lower.Contains("x86_64"))
                            return asset;
                        if (lower.Contains("x86-sciter"))
                            return asset;
                    }
                }
            }

            // Fallback khi không quét được assets
            string tag = (release != null && !string.IsNullOrEmpty(release.TagName)) ? release.TagName : "v1.5.17";
            string ver = tag.TrimStart('v');
            string fallbackFile = "";
            if (info.Arch == "x86" || !info.IsWin10OrLater)
                fallbackFile = string.Format("rustdesk-{0}-x86-sciter.exe", ver);
            else if (info.IsWin10OrLater)
                fallbackFile = string.Format("rustdesk-{0}-x86_64.exe", ver);

            string fallbackUrl = string.Format("https://github.com/ngtrongha/bvdkkh-remote-release/releases/download/{0}/{1}", tag, fallbackFile);
            return new KeyValuePair<string, string>(fallbackFile, fallbackUrl);
        }

        private static int RunSilentBackgroundInstall()
        {
            var info = DetectEnvironment();
            string tempPath = null;

            try
            {
                // 1. Thử lấy từ máy chủ chia sẻ nội bộ mạng LAN trước
                string lanFile = null;
                if (ConnectLanShare(LanSharePath, LanShareUsername, LanSharePassword))
                {
                    lanFile = ResolveLanInstallerFile(info, LanSharePath);
                }

                if (!string.IsNullOrEmpty(lanFile) && File.Exists(lanFile))
                {
                    string fileName = Path.GetFileName(lanFile);
                    tempPath = Path.Combine(Path.GetTempPath(), fileName);
                    CopyFileWithProgress(lanFile, tempPath, null);
                }
                else
                {
                    // 2. Dự phòng: Tải từ GitHub Releases
                    var rel = FetchLatestRelease();
                    var asset = ResolveMatchingAsset(info, rel);
                    tempPath = Path.Combine(Path.GetTempPath(), asset.Key);

                    using (var client = new WebClient())
                    {
                        client.Headers.Add("User-Agent", "BVDKKH-Remote-Installer/1.0");
                        client.DownloadFile(new Uri(asset.Value), tempPath);
                    }
                }

                if (!File.Exists(tempPath)) return 1;

                bool ok = PerformCompleteInstall(tempPath, info, null);
                try { if (File.Exists(tempPath)) File.Delete(tempPath); } catch { }
                return ok ? 0 : 1;
            }
            catch (Exception ex)
            {
                string log = Path.Combine(Path.GetTempPath(), LOG_FILE);
                File.AppendAllText(log, "[" + DateTime.Now + "] Lỗi cài đặt ngầm: " + ex.Message + Environment.NewLine);
                return -1;
            }
        }

        public static bool PerformCompleteInstall(string installerPackagePath, DeviceInfo info, Action<string> logMessage)
        {
            try
            {
                if (logMessage != null) logMessage("Đang dừng dịch vụ và đóng các tiến trình cũ...");
                KillRunningInstancesAndServices(logMessage);

                // 1. Thử gọi bộ cài chính trước để unpack
                if (logMessage != null) logMessage("Đang trích xuất gói cài đặt mới...");
                RunCli(installerPackagePath, "--version");
                Thread.Sleep(1500);

                // Dừng lại một lần nữa để tránh file bị khóa sau khi unpack
                KillRunningInstancesAndServices(null);

                // 2. Xác định thư mục đích trong Program Files
                string pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
                if (!info.IsWin10OrLater && info.Arch == "x86")
                {
                    string pfx86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
                    if (!string.IsNullOrEmpty(pfx86)) pf = pfx86;
                }
                string targetDir = Path.Combine(pf, "BVDKKH - Remote");
                if (!Directory.Exists(targetDir))
                {
                    Directory.CreateDirectory(targetDir);
                }

                // 3. Tìm thư mục giải nén
                string localApp = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                string userProf = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
                string unpackDir = Path.Combine(localApp, "rustdesk");
                if (!Directory.Exists(unpackDir))
                {
                    unpackDir = Path.Combine(userProf, @"AppData\Local\rustdesk");
                }

                if (Directory.Exists(unpackDir))
                {
                    if (logMessage != null) logMessage("Đang sao chép các tệp chương trình phiên bản mới...");
                    CopyDirectoryForce(unpackDir, targetDir);

                    string sourceExe = Path.Combine(unpackDir, "rustdesk.exe");
                    if (File.Exists(sourceExe))
                    {
                        try { File.Copy(sourceExe, Path.Combine(targetDir, "BVĐKKH - Remote.exe"), true); } catch { }
                        try { File.Copy(sourceExe, Path.Combine(targetDir, "BVDKKH - Remote.exe"), true); } catch { }
                        try { File.Copy(sourceExe, Path.Combine(targetDir, "rustdesk.exe"), true); } catch { }

                        string oldUnicodeDir = Path.Combine(pf, "BVĐKKH - Remote");
                        if (Directory.Exists(oldUnicodeDir) && !oldUnicodeDir.Equals(targetDir, StringComparison.OrdinalIgnoreCase))
                        {
                            try { File.Copy(sourceExe, Path.Combine(oldUnicodeDir, "BVĐKKH - Remote.exe"), true); } catch { }
                            try { File.Copy(sourceExe, Path.Combine(oldUnicodeDir, "BVDKKH - Remote.exe"), true); } catch { }
                            try { File.Copy(sourceExe, Path.Combine(oldUnicodeDir, "rustdesk.exe"), true); } catch { }
                        }
                    }
                }

                string mainExe = Path.Combine(targetDir, "BVĐKKH - Remote.exe");
                if (!File.Exists(mainExe)) mainExe = Path.Combine(targetDir, "BVDKKH - Remote.exe");
                if (!File.Exists(mainExe)) mainExe = Path.Combine(targetDir, "rustdesk.exe");

                // 4. Đăng ký Registry Uninstall & InstallState
                RegisterSystemInstallation(targetDir, mainExe);

                // 5. Khởi tạo và BẮT BUỘC KHỞI ĐỘNG Windows Service
                if (logMessage != null) logMessage("Đang kích hoạt dịch vụ chạy ngầm BVĐKKH - Remote...");
                SetupAndStartWindowsService(targetDir, mainExe);

                // 5.5. Tự động cấu hình toàn diện Windows Firewall (vượt tường lửa, mở cổng TCP/UDP, edge traversal)
                if (logMessage != null) logMessage("Đang cấu hình Windows Firewall cho phép kết nối từ xa...");
                ConfigureFirewallRules(targetDir, mainExe);

                // 6. Tạo Shortcut Desktop & Phím tắt
                CreateShortcuts(mainExe);

                // 7. Áp dụng hình nền bệnh viện
                try
                {
                    RunCli(mainExe, "--config allow-remove-wallpaper N");
                }
                catch { }

                // 8. Đăng ký tự chạy khi đăng nhập Windows (Run key) & khởi động Tray
                try
                {
                    using (var runKey = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", true))
                    {
                        if (runKey != null) runKey.SetValue("BVĐKKH - Remote", "\"" + mainExe + "\" --tray");
                    }
                }
                catch { }

                if (logMessage != null) logMessage("Đang khởi động giao diện thanh tác vụ (Tray)...");
                StartTrayProcess(mainExe);

                // 9. Đồng bộ cấu hình bảo mật và mật khẩu thiết bị
                if (logMessage != null) logMessage("Đang đồng bộ mật khẩu và thiết lập bảo mật...");
                PostInstallConfigureAndSync(logMessage);

                return true;
            }
            catch (Exception ex)
            {
                string log = Path.Combine(Path.GetTempPath(), LOG_FILE);
                File.AppendAllText(log, "[" + DateTime.Now + "] Lỗi cài đặt trực tiếp: " + ex.Message + Environment.NewLine);
                return false;
            }
        }

        private static void CopyDirectoryForce(string sourceDir, string destinationDir)
        {
            var dir = new DirectoryInfo(sourceDir);
            if (!dir.Exists) return;

            if (!Directory.Exists(destinationDir))
            {
                Directory.CreateDirectory(destinationDir);
            }

            foreach (var file in dir.GetFiles())
            {
                string targetFilePath = Path.Combine(destinationDir, file.Name);
                int attempts = 0;
                while (attempts < 3)
                {
                    try
                    {
                        file.CopyTo(targetFilePath, true);
                        break;
                    }
                    catch
                    {
                        attempts++;
                        Thread.Sleep(300);
                    }
                }
            }

            foreach (var subDir in dir.GetDirectories())
            {
                string targetSubDir = Path.Combine(destinationDir, subDir.Name);
                CopyDirectoryForce(subDir.FullName, targetSubDir);
            }
        }

        private static void SetupAndStartWindowsService(string targetDir, string mainExe)
        {
            string serviceName = "BVĐKKH - Remote";
            string serviceDisplay = "BVĐKKH - Remote Service";
            string binPath = "\"" + mainExe + "\" --service";

            // Dừng và dọn các service cũ
            RunCli("sc.exe", "stop rustdesk");
            RunCli("sc.exe", "delete rustdesk");
            RunCli("sc.exe", "stop \"BVDKKH - Remote\"");
            RunCli("sc.exe", "delete \"BVDKKH - Remote\"");

            // Cấu hình service chính thức
            RunCli("sc.exe", "create \"" + serviceName + "\" binpath= \"" + binPath + "\" start= auto DisplayName= \"" + serviceDisplay + "\"");
            RunCli("sc.exe", "config \"" + serviceName + "\" binpath= \"" + binPath + "\" start= auto DisplayName= \"" + serviceDisplay + "\"");
            RunCli("sc.exe", "failure \"" + serviceName + "\" reset= 86400 actions= restart/5000/restart/15000/restart/60000");
            RunCli("sc.exe", "start \"" + serviceName + "\"");
            RunCli("net.exe", "start \"" + serviceName + "\"");
        }

        private static void StartTrayProcess(string mainExe)
        {
            try
            {
                var procs = Process.GetProcessesByName("BVĐKKH - Remote");
                if (procs.Length == 0)
                {
                    procs = Process.GetProcessesByName("BVDKKH - Remote");
                }
                var psi = new ProcessStartInfo
                {
                    FileName = mainExe,
                    Arguments = "--tray",
                    UseShellExecute = true
                };
                Process.Start(psi);
            }
            catch { }
        }

        private static void RegisterSystemInstallation(string targetDir, string mainExe)
        {
            string[] names = new string[] { "BVĐKKH - Remote", "BVDKKH - Remote" };
            foreach (var name in names)
            {
                try
                {
                    using (var key = Registry.LocalMachine.CreateSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\" + name))
                    {
                        if (key != null)
                        {
                            key.SetValue("DisplayName", "BVĐKKH - Remote");
                            key.SetValue("DisplayIcon", mainExe + ",0");
                            key.SetValue("DisplayVersion", "1.5.17");
                            key.SetValue("Version", "1.5.17");
                            key.SetValue("Publisher", "Bệnh viện Đa khoa Khánh Hòa");
                            key.SetValue("InstallLocation", targetDir);
                            key.SetValue("UninstallString", "\"" + mainExe + "\" --uninstall");
                            key.SetValue("WindowsInstaller", 0, RegistryValueKind.DWord);
                        }
                    }
                    using (var key = Registry.LocalMachine.CreateSubKey(@"SOFTWARE\" + name + @"\InstallState\" + name))
                    {
                        if (key != null)
                        {
                            key.SetValue("InstallLocation", targetDir);
                        }
                    }
                }
                catch { }
            }
        }

        private static void ConfigureFirewallRules(string targetDir, string mainExe)
        {
            try
            {
                // 1. Dọn dẹp các rule cũ để tránh xung đột
                string[] oldRules = new string[]
                {
                    "BVĐKKH - Remote",
                    "BVĐKKH - Remote Service",
                    "BVDKKH - Remote",
                    "BVDKKH - Remote Service",
                    "RustDesk",
                    "RustDesk Service",
                    "RustDesk - Wake on LAN (WOL)",
                    "BVĐKKH - Remote (TCP In)",
                    "BVĐKKH - Remote (TCP Out)",
                    "BVĐKKH - Remote (UDP In)",
                    "BVĐKKH - Remote (UDP Out)",
                    "BVĐKKH - Remote (WOL In)",
                    "BVĐKKH - Remote App-In",
                    "BVĐKKH - Remote App-Out",
                    "BVĐKKH - Remote Service In",
                    "BVĐKKH - Remote Service Out"
                };
                foreach (var r in oldRules)
                {
                    RunCli("netsh.exe", "advfirewall firewall delete rule name=\"" + r + "\"");
                }

                // 2. Mở theo Chương trình (Program): Cho phép mọi biến thể thực thi trong targetDir (Inbound + Outbound, Mọi Profile)
                string[] exeNames = new string[] { "BVĐKKH - Remote.exe", "BVDKKH - Remote.exe", "rustdesk.exe" };
                foreach (var name in exeNames)
                {
                    string p = Path.Combine(targetDir, name);
                    if (File.Exists(p))
                    {
                        RunCli("netsh.exe", "advfirewall firewall add rule name=\"BVĐKKH - Remote (" + name + " In)\" dir=in action=allow program=\"" + p + "\" profile=any enable=yes");
                        RunCli("netsh.exe", "advfirewall firewall add rule name=\"BVĐKKH - Remote (" + name + " Out)\" dir=out action=allow program=\"" + p + "\" profile=any enable=yes");
                    }
                }

                // 3. Mở theo Tên Dịch vụ Windows (Windows Service)
                RunCli("netsh.exe", "advfirewall firewall add rule name=\"BVĐKKH - Remote Service In\" dir=in action=allow service=\"BVĐKKH - Remote\" profile=any enable=yes");
                RunCli("netsh.exe", "advfirewall firewall add rule name=\"BVĐKKH - Remote Service Out\" dir=out action=allow service=\"BVĐKKH - Remote\" profile=any enable=yes");

                // 4. Mở cổng TCP 21115-21119 (NAT test 21115, Rendezvous 21116, Relay 21117, Web 21118-21119)
                RunCli("netsh.exe", "advfirewall firewall add rule name=\"BVĐKKH - Remote (TCP In)\" dir=in action=allow protocol=TCP localport=21115-21119 profile=any enable=yes");
                RunCli("netsh.exe", "advfirewall firewall add rule name=\"BVĐKKH - Remote (TCP Out)\" dir=out action=allow protocol=TCP remoteport=21115-21119 profile=any enable=yes");

                // 5. Mở cổng UDP 21116 (Heartbeat / Keepalive / Rendezvous registration & P2P hole punching)
                // CỰC KỲ QUAN TRỌNG: edge=yes kích hoạt Edge Traversal (cho phép nhận gói tin đục lỗ NAT từ ngoài vào)
                RunCli("netsh.exe", "advfirewall firewall add rule name=\"BVĐKKH - Remote (UDP In)\" dir=in action=allow protocol=UDP localport=21116 profile=any edge=yes enable=yes");
                RunCli("netsh.exe", "advfirewall firewall add rule name=\"BVĐKKH - Remote (UDP In Fallback)\" dir=in action=allow protocol=UDP localport=21116 profile=any enable=yes");
                RunCli("netsh.exe", "advfirewall firewall add rule name=\"BVĐKKH - Remote (UDP Out)\" dir=out action=allow protocol=UDP remoteport=21116 profile=any enable=yes");

                // 6. Wake on LAN: UDP port 7, 9
                RunCli("netsh.exe", "advfirewall firewall add rule name=\"BVĐKKH - Remote (WOL In)\" dir=in action=allow protocol=UDP localport=7,9 profile=any enable=yes");

                // 7. PowerShell New-NetFirewallRule (Tương thích WFP cao cấp trên Windows 8/10/11)
                try
                {
                    string psRuleCmd =
                        "New-NetFirewallRule -DisplayName 'BVĐKKH - Remote App-In' -Direction Inbound -Program '" + mainExe.Replace("'", "''") + "' -Action Allow -Profile Any -Force -ErrorAction SilentlyContinue; " +
                        "New-NetFirewallRule -DisplayName 'BVĐKKH - Remote App-Out' -Direction Outbound -Program '" + mainExe.Replace("'", "''") + "' -Action Allow -Profile Any -Force -ErrorAction SilentlyContinue; " +
                        "New-NetFirewallRule -DisplayName 'BVĐKKH - Remote Ports-In' -Direction Inbound -Protocol TCP -LocalPort 21115-21119 -Action Allow -Profile Any -Force -ErrorAction SilentlyContinue; " +
                        "New-NetFirewallRule -DisplayName 'BVĐKKH - Remote Heartbeat-In' -Direction Inbound -Protocol UDP -LocalPort 21116 -Action Allow -Profile Any -EdgeTraversalPolicy Allow -Force -ErrorAction SilentlyContinue; " +
                        "New-NetFirewallRule -DisplayName 'BVĐKKH - Remote Heartbeat-Out' -Direction Outbound -Protocol UDP -RemotePort 21116 -Action Allow -Profile Any -Force -ErrorAction SilentlyContinue";
                    RunCli("powershell.exe", "-NoProfile -NonInteractive -Command \"" + psRuleCmd + "\"");
                }
                catch { }
            }
            catch { }
        }

        private static void CreateShortcuts(string mainExe)
        {
            try
            {
                // Dọn sạch toàn bộ shortcut cũ, rác, hoặc gãy link trên Desktop của mọi User trước khi tạo mới
                CleanOldShortcuts();

                string publicDesktop = Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory);
                string lnkPath = Path.Combine(publicDesktop, "BVĐKKH - Remote.lnk");
                CreateLnk(mainExe, lnkPath, "BVĐKKH - Remote");

                string startMenu = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonPrograms), "BVĐKKH - Remote");
                if (!Directory.Exists(startMenu)) Directory.CreateDirectory(startMenu);
                CreateLnk(mainExe, Path.Combine(startMenu, "BVĐKKH - Remote.lnk"), "BVĐKKH - Remote");

                RefreshIconCache();
            }
            catch { }
        }

        private static void CleanOldShortcuts()
        {
            try
            {
                var desktopDirs = new System.Collections.Generic.List<string>();
                string pubDk = Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory);
                if (!string.IsNullOrEmpty(pubDk) && Directory.Exists(pubDk)) desktopDirs.Add(pubDk);

                string usrDk = Environment.GetFolderPath(Environment.SpecialFolder.Desktop);
                if (!string.IsNullOrEmpty(usrDk) && Directory.Exists(usrDk) && !desktopDirs.Contains(usrDk)) desktopDirs.Add(usrDk);

                try
                {
                    string userProf = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
                    string usersRoot = Path.GetDirectoryName(userProf);
                    if (!string.IsNullOrEmpty(usersRoot) && Directory.Exists(usersRoot))
                    {
                        foreach (var uDir in Directory.GetDirectories(usersRoot))
                        {
                            string d = Path.Combine(uDir, "Desktop");
                            if (Directory.Exists(d) && !desktopDirs.Contains(d)) desktopDirs.Add(d);
                        }
                    }
                }
                catch { }

                string[] patterns = new string[] { "*BVĐKKH - Remote*.lnk", "*BVDKKH - Remote*.lnk", "*RustDesk*.lnk", "*rustdesk*.lnk" };
                foreach (var d in desktopDirs)
                {
                    foreach (var pat in patterns)
                    {
                        try
                        {
                            foreach (var f in Directory.GetFiles(d, pat))
                            {
                                try { File.Delete(f); } catch { }
                            }
                        }
                        catch { }
                    }
                }

                var startDirs = new System.Collections.Generic.List<string>();
                string pubSm = Environment.GetFolderPath(Environment.SpecialFolder.CommonPrograms);
                if (!string.IsNullOrEmpty(pubSm) && Directory.Exists(pubSm)) startDirs.Add(pubSm);
                string usrSm = Environment.GetFolderPath(Environment.SpecialFolder.Programs);
                if (!string.IsNullOrEmpty(usrSm) && Directory.Exists(usrSm) && !startDirs.Contains(usrSm)) startDirs.Add(usrSm);

                foreach (var sd in startDirs)
                {
                    foreach (var pat in patterns)
                    {
                        try
                        {
                            foreach (var f in Directory.GetFiles(sd, pat))
                            {
                                try { File.Delete(f); } catch { }
                            }
                        }
                        catch { }
                    }
                    foreach (var sub in new string[] { "RustDesk", "rustdesk", "BVDKKH - Remote" })
                    {
                        try
                        {
                            string subDir = Path.Combine(sd, sub);
                            if (Directory.Exists(subDir)) Directory.Delete(subDir, true);
                        }
                        catch { }
                    }
                }
            }
            catch { }
        }

        private static void CreateLnk(string targetExe, string lnkPath, string description)
        {
            try
            {
                Type shellType = Type.GetTypeFromProgID("WScript.Shell");
                if (shellType != null)
                {
                    dynamic shell = Activator.CreateInstance(shellType);
                    dynamic shortcut = shell.CreateShortcut(lnkPath);
                    shortcut.TargetPath = targetExe;
                    shortcut.WorkingDirectory = Path.GetDirectoryName(targetExe);
                    shortcut.Description = description;
                    shortcut.IconLocation = targetExe + ",0";
                    shortcut.Save();
                }
            }
            catch { }
        }

        private static void RefreshIconCache()
        {
            try
            {
                // SHCNE_ASSOCCHANGED = 0x08000000, SHCNF_IDLIST = 0
                SHChangeNotify(0x08000000, 0, IntPtr.Zero, IntPtr.Zero);
            }
            catch { }
        }

        public static void KillRunningInstancesAndServices(Action<string> logMessage)
        {
            try
            {
                if (logMessage != null) logMessage("Đang dừng dịch vụ và giải phóng tiến trình cũ...");
                string[] svcs = new string[] { "BVĐKKH - Remote", "BVDKKH - Remote", "rustdesk", "RustDesk Service" };
                foreach (var s in svcs)
                {
                    RunCli("sc.exe", "stop \"" + s + "\"");
                }

                string[] procs = new string[] { "BVĐKKH - Remote", "BVDKKH - Remote", "rustdesk", "rustdesk-x64", "rustdesk-x86", "RuntimeBroker_rustdesk", "BaoSuCoIT" };
                foreach (var p in procs)
                {
                    RunCli("taskkill.exe", "/F /T /IM \"" + p + ".exe\"");
                    try
                    {
                        var found = Process.GetProcessesByName(p);
                        foreach (var proc in found)
                        {
                            try { proc.Kill(); } catch { }
                        }
                    }
                    catch { }
                }
                Thread.Sleep(1500);
            }
            catch { }
        }

        public static string DeriveHospitalPassword(string hostname)
        {
            string trimmed = (hostname ?? "").Trim();
            if (string.IsNullOrEmpty(trimmed)) trimmed = Environment.MachineName;
            if (trimmed.Contains("."))
            {
                trimmed = trimmed.Split('.')[0].Trim();
            }
            string clean = trimmed.ToUpperInvariant();
            if (string.IsNullOrEmpty(clean)) return "";

            string input = clean + ":Bvdkkh@RemoteHospitalSecretSalt#2026";
            using (var sha = SHA256.Create())
            {
                byte[] hash = sha.ComputeHash(Encoding.UTF8.GetBytes(input));
                const string chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
                var sb = new StringBuilder("Bv@");
                for (int i = 0; i < 9; i++)
                {
                    sb.Append(chars[hash[i] % chars.Length]);
                }
                return sb.ToString();
            }
        }

        public static string FindInstalledExecutable()
        {
            string pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            string pfx86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
            string[] candidates = new string[]
            {
                Path.Combine(pf, @"BVĐKKH - Remote\BVĐKKH - Remote.exe"),
                Path.Combine(pf, @"BVDKKH - Remote\BVĐKKH - Remote.exe"),
                Path.Combine(pf, @"BVĐKKH - Remote\BVDKKH - Remote.exe"),
                Path.Combine(pf, @"BVDKKH - Remote\BVDKKH - Remote.exe"),
                Path.Combine(pfx86, @"BVĐKKH - Remote\BVĐKKH - Remote.exe"),
                Path.Combine(pfx86, @"BVDKKH - Remote\BVĐKKH - Remote.exe"),
                Path.Combine(pfx86, @"BVĐKKH - Remote\BVDKKH - Remote.exe"),
                Path.Combine(pfx86, @"BVDKKH - Remote\BVDKKH - Remote.exe"),
                Path.Combine(pf, @"RustDesk\RustDesk.exe"),
                Path.Combine(pf, @"RustDesk\rustdesk.exe"),
                Path.Combine(pfx86, @"RustDesk\RustDesk.exe"),
                Path.Combine(pfx86, @"RustDesk\rustdesk.exe")
            };
            foreach (var path in candidates)
            {
                if (File.Exists(path)) return path;
            }

            string[] regKeys = new string[]
            {
                @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\BVĐKKH - Remote",
                @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\BVDKKH - Remote",
                @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk"
            };
            foreach (var regKey in regKeys)
            {
                try
                {
                    using (var key = Registry.LocalMachine.OpenSubKey(regKey))
                    {
                        if (key != null)
                        {
                            string loc = key.GetValue("InstallLocation") as string;
                            if (!string.IsNullOrEmpty(loc))
                            {
                                foreach (var name in new string[] { "BVĐKKH - Remote.exe", "BVDKKH - Remote.exe", "RustDesk.exe", "rustdesk.exe" })
                                {
                                    string exe = Path.Combine(loc, name);
                                    if (File.Exists(exe)) return exe;
                                }
                            }
                        }
                    }
                }
                catch { }
            }
            return null;
        }

        public static string GetRustDeskId(string installedExe)
        {
            string appData = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData);
            string userAppData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string[] tomlPaths = new string[]
            {
                Path.Combine(appData, @"BVDKKH - Remote\config\BVDKKH - Remote.toml"),
                Path.Combine(appData, @"RustDesk\config\RustDesk.toml"),
                Path.Combine(userAppData, @"BVDKKH - Remote\config\BVDKKH - Remote.toml"),
                Path.Combine(userAppData, @"RustDesk\config\RustDesk.toml")
            };
            foreach (var path in tomlPaths)
            {
                try
                {
                    if (File.Exists(path))
                    {
                        string content = File.ReadAllText(path);
                        var match = Regex.Match(content, @"id\s*=\s*['""]([^'""]+)['""]");
                        if (match.Success)
                        {
                            string id = match.Groups[1].Value.Replace(" ", "").Trim();
                            if (!string.IsNullOrEmpty(id)) return id;
                        }
                    }
                }
                catch { }
            }

            if (!string.IsNullOrEmpty(installedExe) && File.Exists(installedExe))
            {
                try
                {
                    var psi = new ProcessStartInfo
                    {
                        FileName = installedExe,
                        Arguments = "--get-id",
                        UseShellExecute = false,
                        RedirectStandardOutput = true,
                        CreateNoWindow = true
                    };
                    using (var proc = Process.Start(psi))
                    {
                        string outStr = proc.StandardOutput.ReadToEnd().Trim();
                        proc.WaitForExit(3000);
                        string cleanId = outStr.Replace(" ", "").Trim();
                        if (!string.IsNullOrEmpty(cleanId) && cleanId.Length >= 6)
                        {
                            return cleanId;
                        }
                    }
                }
                catch { }
            }
            return null;
        }

        private static void RunCli(string exe, string args)
        {
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = exe,
                    Arguments = args,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };
                using (var proc = Process.Start(psi))
                {
                    proc.WaitForExit(4000);
                }
            }
            catch { }
        }

        public static void PostInstallConfigureAndSync(Action<string> logMessage)
        {
            try
            {
                Thread.Sleep(1500);
                string installedExe = Program.FindInstalledExecutable();
                string hostname = Environment.MachineName;
                string devicePassword = DeriveHospitalPassword(hostname);

                if (!string.IsNullOrEmpty(installedExe) && !string.IsNullOrEmpty(devicePassword))
                {
                    if (logMessage != null) logMessage("Đang cấu hình mật khẩu cố định theo tên máy...");
                    RunCli(installedExe, "--option disable-change-permanent-password N");
                    RunCli(installedExe, string.Format("--password \"{0}\"", devicePassword));
                    RunCli(installedExe, string.Format("--set-unlock-pin \"{0}\"", devicePassword));
                    RunCli(installedExe, "--option verification-method use-permanent-password");
                    RunCli(installedExe, "--option approve-mode password");
                    RunCli(installedExe, "--option disable-change-permanent-password Y");
                }

                string rdId = GetRustDeskId(installedExe);
                if (!string.IsNullOrEmpty(rdId) && !string.IsNullOrEmpty(devicePassword))
                {
                    if (logMessage != null) logMessage(string.Format("Đang đồng bộ mật khẩu ID {0} lên máy chủ trung tâm...", rdId));
                    string url = string.Format("http://172.16.3.28:21114/api/admin/devices/{0}/control-password", rdId);
                    string body = string.Format("{{\"password\":\"{0}\"}}", devicePassword);
                    var req = (HttpWebRequest)WebRequest.Create(url);
                    req.Method = "POST";
                    req.ContentType = "application/json";
                    req.Timeout = 3000;
                    byte[] bytes = Encoding.UTF8.GetBytes(body);
                    req.ContentLength = bytes.Length;
                    using (var stream = req.GetRequestStream())
                    {
                        stream.Write(bytes, 0, bytes.Length);
                    }
                    using (var resp = req.GetResponse())
                    {
                    }
                }
            }
            catch (Exception ex)
            {
                try
                {
                    string log = Path.Combine(Path.GetTempPath(), LOG_FILE);
                    File.AppendAllText(log, "[" + DateTime.Now + "] Lỗi cấu hình/đồng bộ sau cài đặt: " + ex.Message + Environment.NewLine);
                }
                catch { }
            }
        }
    }

    // =========================================================================
    // GIAO DIỆN ĐỒ HỌA TRỰC QUAN (MODERN WINFORMS GUI)
    // =========================================================================
    public class ModernInstallerForm : Form
    {
        [DllImport("user32.dll")]
        public static extern bool ReleaseCapture();
        [DllImport("user32.dll")]
        public static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);
        private const int WM_NCLBUTTONDOWN = 0xA1;
        private const int HT_CAPTION = 0x2;

        public int ExitCode = 0;

        private Label lblHeaderTitle;
        private Label lblHeaderSub;
        private Label lblClose;
        private Panel pnlHeader;

        private Panel pnlBadge;
        private Label lblBadge;

        private Label lblStatus;
        private Label lblDetail;
        private ModernProgressBar progressBar;
        private Button btnAction;
        private Button btnExit;
        private Label lblFooter;

        private WebClient webClient;
        private string downloadedFile = "";

        public ModernInstallerForm()
        {
            InitializeComponent();
        }

        private void InitializeComponent()
        {
            this.Text = "BVĐKKH - Remote | Trình cài đặt tự động";
            this.Size = new Size(540, 370);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.None;
            this.BackColor = Color.FromArgb(248, 250, 252); // Slate 50
            this.DoubleBuffered = true;

            try
            {
                string exePath = Process.GetCurrentProcess().MainModule.FileName;
                this.Icon = Icon.ExtractAssociatedIcon(exePath);
                this.ShowIcon = true;
            }
            catch { }

            // 1. Header Bar (Rose Red #E11D48)
            pnlHeader = new Panel
            {
                Dock = DockStyle.Top,
                Height = 80,
                BackColor = Color.FromArgb(225, 29, 72) // #E11D48
            };
            pnlHeader.MouseDown += (s, e) =>
            {
                if (e.Button == MouseButtons.Left)
                {
                    ReleaseCapture();
                    SendMessage(this.Handle, WM_NCLBUTTONDOWN, HT_CAPTION, 0);
                }
            };

            var picIcon = new PictureBox
            {
                Location = new Point(18, 18),
                Size = new Size(42, 42),
                SizeMode = PictureBoxSizeMode.Zoom,
                BackColor = Color.Transparent
            };
            try
            {
                if (this.Icon != null) picIcon.Image = this.Icon.ToBitmap();
            }
            catch { }
            picIcon.MouseDown += (s, e) =>
            {
                if (e.Button == MouseButtons.Left) { ReleaseCapture(); SendMessage(this.Handle, WM_NCLBUTTONDOWN, HT_CAPTION, 0); }
            };
            pnlHeader.Controls.Add(picIcon);

            lblHeaderTitle = new Label
            {
                Text = "BỆNH VIỆN ĐA KHOA TỈNH KHÁNH HÒA",
                ForeColor = Color.White,
                Font = new Font("Segoe UI", 11.5f, FontStyle.Bold),
                Location = new Point(68, 16),
                AutoSize = true
            };
            lblHeaderTitle.MouseDown += (s, e) =>
            {
                if (e.Button == MouseButtons.Left) { ReleaseCapture(); SendMessage(this.Handle, WM_NCLBUTTONDOWN, HT_CAPTION, 0); }
            };

            lblHeaderSub = new Label
            {
                Text = "Hệ thống hỗ trợ kỹ thuật từ xa • Trình cài đặt tự động thông minh",
                ForeColor = Color.FromArgb(254, 205, 211), // Rose 200
                Font = new Font("Segoe UI", 8.8f, FontStyle.Regular),
                Location = new Point(68, 42),
                AutoSize = true
            };
            lblHeaderSub.MouseDown += (s, e) =>
            {
                if (e.Button == MouseButtons.Left) { ReleaseCapture(); SendMessage(this.Handle, WM_NCLBUTTONDOWN, HT_CAPTION, 0); }
            };

            lblClose = new Label
            {
                Text = "✕",
                ForeColor = Color.White,
                Font = new Font("Segoe UI", 11f, FontStyle.Regular),
                Location = new Point(505, 12),
                Size = new Size(24, 24),
                TextAlign = ContentAlignment.MiddleCenter,
                Cursor = Cursors.Hand
            };
            lblClose.MouseEnter += (s, e) => lblClose.ForeColor = Color.FromArgb(254, 205, 211);
            lblClose.MouseLeave += (s, e) => lblClose.ForeColor = Color.White;
            lblClose.Click += (s, e) => { CancelAndExit(); };

            pnlHeader.Controls.Add(lblHeaderTitle);
            pnlHeader.Controls.Add(lblHeaderSub);
            pnlHeader.Controls.Add(lblClose);
            this.Controls.Add(pnlHeader);

            // 2. Device Info Badge
            pnlBadge = new Panel
            {
                Location = new Point(24, 98),
                Size = new Size(492, 36),
                BackColor = Color.FromArgb(241, 245, 249) // Slate 100
            };
            pnlBadge.Paint += (s, e) =>
            {
                using (var pen = new Pen(Color.FromArgb(226, 232, 240), 1))
                {
                    e.Graphics.DrawRectangle(pen, 0, 0, pnlBadge.Width - 1, pnlBadge.Height - 1);
                }
            };

            lblBadge = new Label
            {
                Text = "Đang nhận diện thiết bị...",
                Font = new Font("Segoe UI", 8.8f, FontStyle.Bold),
                ForeColor = Color.FromArgb(51, 65, 85),
                Dock = DockStyle.Fill,
                TextAlign = ContentAlignment.MiddleCenter
            };
            pnlBadge.Controls.Add(lblBadge);
            this.Controls.Add(pnlBadge);

            // 3. Status Text & Detail
            lblStatus = new Label
            {
                Text = "Đang kiểm tra gói cài đặt...",
                Font = new Font("Segoe UI", 10.5f, FontStyle.Bold),
                ForeColor = Color.FromArgb(15, 23, 42),
                Location = new Point(24, 150),
                Size = new Size(492, 26)
            };
            this.Controls.Add(lblStatus);

            lblDetail = new Label
            {
                Text = "Vui lòng giữ kết nối trong quá trình thiết lập.",
                Font = new Font("Segoe UI", 9f, FontStyle.Regular),
                ForeColor = Color.FromArgb(100, 116, 139),
                Location = new Point(24, 178),
                Size = new Size(492, 20)
            };
            this.Controls.Add(lblDetail);

            // 4. Modern Progress Bar
            progressBar = new ModernProgressBar
            {
                Location = new Point(24, 206),
                Size = new Size(492, 12),
                Value = 0
            };
            this.Controls.Add(progressBar);

            // 5. Buttons
            btnAction = new Button
            {
                Text = "ĐANG CHUẨN BỊ...",
                Font = new Font("Segoe UI", 9.5f, FontStyle.Bold),
                BackColor = Color.FromArgb(225, 29, 72),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Location = new Point(320, 246),
                Size = new Size(196, 42),
                Cursor = Cursors.Hand,
                Enabled = false
            };
            btnAction.FlatAppearance.BorderSize = 0;
            btnAction.Click += (s, e) => { OnActionClick(); };
            this.Controls.Add(btnAction);

            btnExit = new Button
            {
                Text = "HỦY BỎ",
                Font = new Font("Segoe UI", 9.5f, FontStyle.Regular),
                BackColor = Color.FromArgb(241, 245, 249),
                ForeColor = Color.FromArgb(71, 85, 105),
                FlatStyle = FlatStyle.Flat,
                Location = new Point(210, 246),
                Size = new Size(100, 42),
                Cursor = Cursors.Hand
            };
            btnExit.FlatAppearance.BorderColor = Color.FromArgb(203, 213, 225);
            btnExit.Click += (s, e) => { CancelAndExit(); };
            this.Controls.Add(btnExit);

            // 6. Footer
            lblFooter = new Label
            {
                Text = "Tự động tối ưu theo hệ điều hành và đồng bộ cấu hình bảo mật.",
                Font = new Font("Segoe UI", 8.2f, FontStyle.Italic),
                ForeColor = Color.FromArgb(148, 163, 184),
                Location = new Point(24, 310),
                Size = new Size(492, 20),
                TextAlign = ContentAlignment.MiddleCenter
            };
            this.Controls.Add(lblFooter);

            // Viền ngoài của Form
            this.Paint += (s, e) =>
            {
                using (var pen = new Pen(Color.FromArgb(203, 213, 225), 1))
                {
                    e.Graphics.DrawRectangle(pen, 0, 0, this.Width - 1, this.Height - 1);
                }
            };

            this.Shown += (s, e) => { StartInstallationFlow(); };
        }

        private void StartInstallationFlow()
        {
            var thread = new Thread(() =>
            {
                try
                {
                    // Bước 1: Nhận diện thiết bị
                    var info = Program.DetectEnvironment();
                    this.Invoke(new Action(() =>
                    {
                        lblBadge.Text = string.Format("🖥 Hệ điều hành: {0} ({1})   •   Trạng thái: Tương thích", info.OsName, info.Arch);
                    }));

                    // Bước 2: Kiểm tra máy chủ chia sẻ mạng LAN trước
                    this.Invoke(new Action(() =>
                    {
                        lblStatus.Text = "Đang kiểm tra gói cài đặt từ máy chủ nội bộ...";
                        lblDetail.Text = "Đang kết nối " + Program.LanSharePath + "...";
                        progressBar.Value = 15;
                    }));

                    string lanFile = null;
                    if (Program.ConnectLanShare(Program.LanSharePath, Program.LanShareUsername, Program.LanSharePassword))
                    {
                        lanFile = Program.ResolveLanInstallerFile(info, Program.LanSharePath);
                    }

                    string tempPath = null;

                    if (!string.IsNullOrEmpty(lanFile) && File.Exists(lanFile))
                    {
                        string fileName = Path.GetFileName(lanFile);
                        tempPath = Path.Combine(Path.GetTempPath(), fileName);
                        downloadedFile = tempPath;

                        this.Invoke(new Action(() =>
                        {
                            lblBadge.Text = string.Format("🖥 {0} ({1})   •   Nguồn: Máy chủ nội bộ LAN", info.OsName, info.Arch);
                            lblStatus.Text = "Đang sao chép từ máy chủ nội bộ: " + fileName;
                            lblDetail.Text = "Chuẩn bị sao chép dữ liệu...";
                            progressBar.Value = 25;
                        }));

                        Program.CopyFileWithProgress(lanFile, tempPath, (copied, total) =>
                        {
                            try
                            {
                                this.BeginInvoke(new Action(() =>
                                {
                                    int val = 25 + (int)(((double)copied / total) * 55.0); // 25% -> 80%
                                    progressBar.Value = Math.Min(val, 80);
                                    double mbRec = copied / 1024.0 / 1024.0;
                                    double mbTotal = total / 1024.0 / 1024.0;
                                    int pct = (int)((copied * 100) / total);
                                    lblDetail.Text = string.Format("Đã sao chép: {0:F1} MB / {1:F1} MB ({2}%)", mbRec, mbTotal, pct);
                                }));
                            }
                            catch { }
                        });
                    }
                    else
                    {
                        // Bước 2b: Dự phòng tải qua GitHub Releases khi không kết nối được LAN
                        this.Invoke(new Action(() =>
                        {
                            lblStatus.Text = "Đang kiểm tra phiên bản mới nhất từ GitHub...";
                            lblDetail.Text = "Đang kết nối kho phát hành chính thức...";
                            progressBar.Value = 20;
                        }));

                        var rel = Program.FetchLatestRelease();
                        var asset = Program.ResolveMatchingAsset(info, rel);
                        string tag = rel.TagName;

                        this.Invoke(new Action(() =>
                        {
                            lblBadge.Text = string.Format("🖥 {0} ({1})   •   Phiên bản: {2}", info.OsName, info.Arch, tag);
                            lblStatus.Text = "Đang tải gói cài đặt từ GitHub: " + asset.Key;
                            lblDetail.Text = "Chuẩn bị tải dữ liệu...";
                            progressBar.Value = 25;
                        }));

                        tempPath = Path.Combine(Path.GetTempPath(), asset.Key);
                        downloadedFile = tempPath;

                        using (webClient = new WebClient())
                        {
                            webClient.Headers.Add("User-Agent", "BVDKKH-Remote-Installer/1.0");
                            webClient.DownloadProgressChanged += (s, e) =>
                            {
                                try
                                {
                                    this.BeginInvoke(new Action(() =>
                                    {
                                        int val = 25 + (int)(e.ProgressPercentage * 0.55); // Từ 25% -> 80%
                                        progressBar.Value = Math.Min(val, 80);
                                        double mbRec = e.BytesReceived / 1024.0 / 1024.0;
                                        double mbTotal = e.TotalBytesToReceive / 1024.0 / 1024.0;
                                        lblDetail.Text = string.Format("Đã tải: {0:F1} MB / {1:F1} MB ({2}%)", mbRec, mbTotal, e.ProgressPercentage);
                                    }));
                                }
                                catch { }
                            };

                            webClient.DownloadFile(new Uri(asset.Value), tempPath);
                        }
                    }

                    // Bước 4: Thực thi cài đặt và kích hoạt dịch vụ hoàn chỉnh
                    this.Invoke(new Action(() =>
                    {
                        lblStatus.Text = "Đang cài đặt và cập nhật hệ thống...";
                        lblDetail.Text = "Đang sao chép tệp chương trình và cấu hình dịch vụ...";
                        progressBar.Value = 85;
                    }));

                    bool installOk = Program.PerformCompleteInstall(tempPath, info, msg =>
                    {
                        try { this.BeginInvoke(new Action(() => { lblDetail.Text = msg; })); } catch { }
                    });

                    try { if (File.Exists(tempPath)) File.Delete(tempPath); } catch { }

                    if (!installOk)
                    {
                        throw new Exception("Quá trình cài đặt trực tiếp gặp sự cố. Vui lòng thử lại với quyền Administrator.");
                    }

                    // Bước 5: Cập nhật giao diện hoàn tất
                    this.Invoke(new Action(() =>
                    {
                        progressBar.Value = 100;
                        progressBar.BarColor = Color.FromArgb(16, 185, 129); // Green 500

                        lblStatus.Text = "✓ CÀI ĐẶT THÀNH CÔNG!";
                        lblStatus.ForeColor = Color.FromArgb(5, 150, 105); // Green 600
                        lblDetail.Text = "BVĐKKH - Remote đã sẵn sàng hỗ trợ kỹ thuật từ xa.";

                        btnAction.Text = "MỞ ỨNG DỤNG NGAY";
                        btnAction.BackColor = Color.FromArgb(16, 185, 129);
                        btnAction.Enabled = true;

                        btnExit.Text = "ĐÓNG";
                    }));
                }
                catch (ThreadAbortException)
                {
                    // Hủy cài đặt
                }
                catch (Exception ex)
                {
                    this.Invoke(new Action(() =>
                    {
                        lblStatus.Text = "✕ Quá trình cài đặt gián đoạn";
                        lblStatus.ForeColor = Color.FromArgb(220, 38, 38);
                        lblDetail.Text = "Lỗi: " + ex.Message;
                        btnExit.Text = "ĐÓNG";
                        btnAction.Text = "THỬ LẠI";
                        btnAction.Enabled = true;
                    }));
                }
            });

            thread.IsBackground = true;
            thread.Start();
        }

        private void OnActionClick()
        {
            if (btnAction.Text == "MỞ ỨNG DỤNG NGAY")
            {
                try
                {
                    string pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
                    string pfx86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
                    string[] possiblePaths = new string[]
                    {
                        Path.Combine(pf, @"BVĐKKH - Remote\BVĐKKH - Remote.exe"),
                        Path.Combine(pf, @"BVDKKH - Remote\BVDKKH - Remote.exe"),
                        Path.Combine(pfx86, @"BVĐKKH - Remote\BVĐKKH - Remote.exe"),
                        Path.Combine(pfx86, @"BVDKKH - Remote\BVDKKH - Remote.exe"),
                        Path.Combine(pf, @"RustDesk\RustDesk.exe"),
                        Path.Combine(pfx86, @"RustDesk\RustDesk.exe"),
                        @"C:\Program Files\BVĐKKH - Remote\BVĐKKH - Remote.exe",
                        @"C:\Program Files\BVDKKH - Remote\BVDKKH - Remote.exe",
                        @"C:\Program Files (x86)\BVĐKKH - Remote\BVĐKKH - Remote.exe",
                        @"C:\Program Files (x86)\BVDKKH - Remote\BVDKKH - Remote.exe",
                        @"C:\Program Files\RustDesk\RustDesk.exe",
                        @"C:\Program Files (x86)\RustDesk\RustDesk.exe"
                    };

                    bool launched = false;
                    string installedExe = Program.FindInstalledExecutable();
                    if (!string.IsNullOrEmpty(installedExe) && File.Exists(installedExe))
                    {
                        Process.Start(installedExe);
                        launched = true;
                    }
                    else
                    {
                        foreach (var p in possiblePaths)
                        {
                            if (File.Exists(p))
                            {
                                Process.Start(p);
                                launched = true;
                                break;
                            }
                        }
                    }

                    if (!launched)
                    {
                        string desktopPath = Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory);
                        string userDesktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
                        string[] links = new string[]
                        {
                            Path.Combine(desktopPath, "BVĐKKH - Remote.lnk"),
                            Path.Combine(desktopPath, "BVDKKH - Remote.lnk"),
                            Path.Combine(desktopPath, "RustDesk.lnk"),
                            Path.Combine(userDesktop, "BVĐKKH - Remote.lnk"),
                            Path.Combine(userDesktop, "BVDKKH - Remote.lnk"),
                            Path.Combine(userDesktop, "RustDesk.lnk")
                        };
                        foreach (var lnk in links)
                        {
                            if (File.Exists(lnk))
                            {
                                Process.Start(lnk);
                                break;
                            }
                        }
                    }
                }
                catch { }
                this.Close();
            }
            else if (btnAction.Text == "THỬ LẠI")
            {
                btnAction.Enabled = false;
                btnAction.Text = "ĐANG CHUẨN BỊ...";
                progressBar.BarColor = Color.FromArgb(225, 29, 72);
                progressBar.Value = 0;
                StartInstallationFlow();
            }
        }

        private void CancelAndExit()
        {
            try
            {
                if (webClient != null && webClient.IsBusy)
                {
                    webClient.CancelAsync();
                }
            }
            catch { }

            try
            {
                if (!string.IsNullOrEmpty(downloadedFile) && File.Exists(downloadedFile))
                {
                    File.Delete(downloadedFile);
                }
            }
            catch { }

            this.Close();
        }
    }

    // =========================================================================
    // PROGRESS BAR TỰ VẼ HIỆN ĐẠI (SMOOTH MODERN PROGRESS BAR)
    // =========================================================================
    public class ModernProgressBar : Control
    {
        private int _value = 0;
        public Color BarColor = Color.FromArgb(225, 29, 72); // Rose Red

        public int Value
        {
            get { return _value; }
            set
            {
                _value = Math.Max(0, Math.Min(100, value));
                this.Invalidate();
            }
        }

        public ModernProgressBar()
        {
            this.SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer, true);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            // Track background
            using (var brush = new SolidBrush(Color.FromArgb(226, 232, 240)))
            {
                g.FillRoundedRectangle(brush, new Rectangle(0, 0, this.Width, this.Height), 6);
            }

            // Fill bar
            if (_value > 0)
            {
                int fillWidth = (int)((this.Width * _value) / 100.0);
                if (fillWidth > 6)
                {
                    using (var brush = new SolidBrush(BarColor))
                    {
                        g.FillRoundedRectangle(brush, new Rectangle(0, 0, fillWidth, this.Height), 6);
                    }
                }
            }
        }
    }

    public static class GraphicsExtensions
    {
        public static void FillRoundedRectangle(this Graphics g, Brush brush, Rectangle bounds, int cornerRadius)
        {
            using (var path = CreateRoundedRectanglePath(bounds, cornerRadius))
            {
                g.FillPath(brush, path);
            }
        }

        private static GraphicsPath CreateRoundedRectanglePath(Rectangle bounds, int radius)
        {
            var path = new GraphicsPath();
            int diameter = radius * 2;
            var arc = new Rectangle(bounds.Location, new Size(diameter, diameter));

            path.AddArc(arc, 180, 90);
            arc.X = bounds.Right - diameter;
            path.AddArc(arc, 270, 90);
            arc.Y = bounds.Bottom - diameter;
            path.AddArc(arc, 0, 90);
            arc.X = bounds.Left;
            path.AddArc(arc, 90, 90);
            path.CloseFigure();
            return path;
        }
    }
}
