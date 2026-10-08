// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remoter
// Author: Nguyễn Trọng Hà
// Description: Trình cài đặt tự động (Online Bootstrapper) cho BVĐKKH - Remote
//              Tự động nhận diện Windows (Win7/8 vs Win10/11, x64/x86/ARM64),
//              tải bản mới nhất từ GitHub Releases và cài đặt ngầm (Silent Install).

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.Win32;

namespace BVDKKH.Remote.AutoInstaller
{
    class Program
    {
        private const string GITHUB_API_URL = "https://api.github.com/repos/ngtrongha/bvdkkh-remote-release/releases/latest";
        private const string LOG_FILE = "bvdkkh_installer.log";

        [DllImport("kernel32.dll")]
        private static extern IntPtr GetConsoleWindow();

        [DllImport("user32.dll")]
        private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

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

        private static bool isSilentMode = false;
        private static string logPath = "";

        static int Main(string[] args)
        {
            try
            {
                Console.OutputEncoding = Encoding.UTF8;
            }
            catch { }

            logPath = Path.Combine(Path.GetTempPath(), LOG_FILE);

            bool isCheckOnly = false;

            // Kiểm tra cờ silent install và check only
            foreach (var arg in args)
            {
                string a = arg.Trim().ToLowerInvariant();
                if (a == "/s" || a == "-s" || a == "/silent" || a == "--silent" || a == "/quiet" || a == "/q")
                {
                    isSilentMode = true;
                }
                else if (a == "--check" || a == "/check" || a == "--test" || a == "/test")
                {
                    isCheckOnly = true;
                }
            }

            if (isSilentMode)
            {
                IntPtr hWnd = GetConsoleWindow();
                if (hWnd != IntPtr.Zero)
                {
                    ShowWindow(hWnd, 0); // SW_HIDE
                }
            }

            Log("=========================================================");
            Log("  BVĐKKH - REMOTE | TRÌNH CÀI ĐẶT TỰ ĐỘNG THÔNG MINH");
            Log("=========================================================");

            // 1. Kiểm tra quyền Quản trị viên (UAC) nếu cần cài đặt
            if (!isCheckOnly && !IsAdministrator())
            {
                Log("[*] Yêu cầu quyền Quản trị viên (Administrator). Đang thử nâng quyền...");
                int elevatedExit = ElevateProcess(args);
                if (elevatedExit == 0)
                {
                    return 0;
                }
                Log("[*] Tiếp tục thực thi cài đặt trong phiên hiện tại...");
            }

            // 2. Kích hoạt TLS 1.2 cho Windows 7/8/10
            ConfigureSecurityProtocol();

            // 3. Nhận diện hệ điều hành và kiến trúc CPU
            bool isWin10OrLater = CheckIsWindows10OrLater();
            string arch = DetectCpuArchitecture();
            string osName = isWin10OrLater ? "Windows 10/11" : "Windows 7/8 (LTS)";

            Log(string.Format("[1/4] Nhận diện thiết bị: {0} ({1})", osName, arch));

            // 4. Lấy thông tin phiên bản mới nhất từ GitHub
            Log("[2/4] Đang kiểm tra bản phát hành mới nhất từ máy chủ GitHub...");
            string releaseJson = "";
            string tagName = "";
            try
            {
                using (var client = new WebClient())
                {
                    client.Encoding = Encoding.UTF8;
                    client.Headers.Add("User-Agent", "BVDKKH-Remote-Installer/1.0");
                    releaseJson = client.DownloadString(GITHUB_API_URL);
                }

                var matchTag = Regex.Match(releaseJson, "\"tag_name\"\\s*:\\s*\"([^\"]+)\"");
                if (matchTag.Success)
                {
                    tagName = matchTag.Groups[1].Value;
                }
            }
            catch (Exception ex)
            {
                Log("[!] Cảnh báo: Không thể gọi GitHub API (có thể do giới hạn kết nối): " + ex.Message);
            }

            // 5. Tìm URL file cài đặt phù hợp với thiết bị
            string downloadUrl = "";
            string fileName = "";

            if (!string.IsNullOrEmpty(releaseJson))
            {
                var assets = ParseAssetsFromJson(releaseJson);
                foreach (var asset in assets)
                {
                    string name = asset.Key.ToLowerInvariant();
                    string url = asset.Value;

                    if (!name.EndsWith(".exe") || name.EndsWith(".apk") || name.Contains("setup"))
                    {
                        // Chỉ chọn file thực thi của ứng dụng
                    }

                    if (arch == "ARM64" && name.Contains("aarch64") && name.EndsWith(".exe"))
                    {
                        downloadUrl = url;
                        fileName = asset.Key;
                        break;
                    }
                    else if (arch == "x86" && name.Contains("x86-sciter") && name.EndsWith(".exe"))
                    {
                        downloadUrl = url;
                        fileName = asset.Key;
                        break;
                    }
                    else if (isWin10OrLater && arch == "x64")
                    {
                        if (name.Contains("x86_64") && !name.Contains("win7") && name.EndsWith(".exe"))
                        {
                            downloadUrl = url;
                            fileName = asset.Key;
                            break;
                        }
                    }
                    else if (!isWin10OrLater && arch == "x64")
                    {
                        if (name.Contains("win7") && name.Contains("x86_64") && name.EndsWith(".exe"))
                        {
                            downloadUrl = url;
                            fileName = asset.Key;
                            break;
                        }
                    }
                }
            }

            // Fallback trực tiếp nếu không parse được qua API
            if (string.IsNullOrEmpty(downloadUrl))
            {
                string tag = !string.IsNullOrEmpty(tagName) ? tagName : "v1.5.16";
                string verNum = tag.TrimStart('v');
                if (arch == "x86")
                {
                    fileName = string.Format("rustdesk-{0}-x86-sciter.exe", verNum);
                }
                else if (isWin10OrLater)
                {
                    fileName = string.Format("rustdesk-{0}-x86_64.exe", verNum);
                }
                else
                {
                    fileName = string.Format("rustdesk-{0}-win7-x86_64.exe", verNum);
                }

                downloadUrl = string.Format("https://github.com/ngtrongha/bvdkkh-remote-release/releases/download/{0}/{1}", tag, fileName);
            }
            else
            {
                Log(string.Format("[*] Tìm thấy gói cài đặt tối ưu: {0}", fileName));
            }

            if (isCheckOnly)
            {
                Log("[*] Kết quả kiểm tra (--check):");
                Log(string.Format("    - Thiết bị: {0} ({1})", osName, arch));
                Log(string.Format("    - Phiên bản: {0}", !string.IsNullOrEmpty(tagName) ? tagName : "v1.5.16"));
                Log(string.Format("    - Gói phù hợp: {0}", fileName));
                Log(string.Format("    - Đường dẫn tải: {0}", downloadUrl));
                Log("[V] Kiểm tra thành công! Thiết bị hoàn toàn tương thích.");
                return 0;
            }

            // 6. Tải gói cài đặt về thư mục tạm %TEMP%
            string tempInstallerPath = Path.Combine(Path.GetTempPath(), fileName);
            Log(string.Format("[3/4] Đang tải gói cài đặt từ máy chủ ({0})...", fileName));

            bool downloadOk = DownloadFileWithProgress(downloadUrl, tempInstallerPath);
            if (!downloadOk || !File.Exists(tempInstallerPath))
            {
                Log("[X] Thất bại khi tải file cài đặt. Vui lòng kiểm tra lại kết nối mạng!");
                if (!isSilentMode)
                {
                    Console.WriteLine("\nNhấn phím bất kỳ để thoát...");
                    Console.ReadKey();
                }
                return 1;
            }

            // 7. Thực hiện cài đặt ngầm (Silent Install)
            Log("[4/4] Đang tiến hành cài đặt ngầm (Silent Install) vào hệ thống...");
            int exitCode = RunSilentInstall(tempInstallerPath);

            // 8. Dọn dẹp file tạm
            try
            {
                if (File.Exists(tempInstallerPath))
                {
                    File.Delete(tempInstallerPath);
                }
            }
            catch { }

            if (exitCode == 0)
            {
                Log("[V] CÀI ĐẶT THÀNH CÔNG! BVĐKKH - Remote đã sẵn sàng sử dụng.");
            }
            else
            {
                Log(string.Format("[!] Quá trình cài đặt kết thúc với mã thoát: {0}", exitCode));
            }

            if (!isSilentMode)
            {
                Console.WriteLine("\nHoàn tất! Cửa sổ sẽ tự đóng sau 3 giây...");
                System.Threading.Thread.Sleep(3000);
            }

            return exitCode;
        }

        private static bool IsAdministrator()
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

        private static int ElevateProcess(string[] args)
        {
            try
            {
                string exePath = Process.GetCurrentProcess().MainModule.FileName;
                string arguments = string.Join(" ", args);

                var startInfo = new ProcessStartInfo
                {
                    FileName = exePath,
                    Arguments = arguments,
                    UseShellExecute = true,
                    Verb = "runas"
                };

                var proc = Process.Start(startInfo);
                proc.WaitForExit();
                return proc.ExitCode;
            }
            catch (Exception ex)
            {
                Log("[X] Không thể nâng quyền Quản trị: " + ex.Message);
                return 1;
            }
        }

        private static void ConfigureSecurityProtocol()
        {
            try
            {
                // Cho phép TLS 1.2 (3072), TLS 1.1 (768), TLS 1.0 (192)
                ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072 | (SecurityProtocolType)768 | SecurityProtocolType.Tls;
                ServicePointManager.ServerCertificateValidationCallback = (sender, cert, chain, errors) => true;
            }
            catch { }
        }

        private static bool CheckIsWindows10OrLater()
        {
            try
            {
                // Cách 1: Registry CurrentMajorVersionNumber
                object regMajor = Registry.GetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion", "CurrentMajorVersionNumber", null);
                if (regMajor != null && Convert.ToInt32(regMajor) >= 10)
                {
                    return true;
                }

                // Cách 2: Environment.OSVersion
                if (Environment.OSVersion.Version.Major >= 10)
                {
                    return true;
                }
            }
            catch { }
            return false;
        }

        private static string DetectCpuArchitecture()
        {
            try
            {
                var sysInfo = new SYSTEM_INFO();
                GetNativeSystemInfo(ref sysInfo);
                switch (sysInfo.wProcessorArchitecture)
                {
                    case PROCESSOR_ARCHITECTURE_AMD64:
                        return "x64";
                    case PROCESSOR_ARCHITECTURE_ARM64:
                        return "ARM64";
                    case PROCESSOR_ARCHITECTURE_INTEL:
                        return "x86";
                    default:
                        return Environment.Is64BitOperatingSystem ? "x64" : "x86";
                }
            }
            catch
            {
                return Environment.Is64BitOperatingSystem ? "x64" : "x86";
            }
        }

        private static Dictionary<string, string> ParseAssetsFromJson(string json)
        {
            var dict = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            var matches = Regex.Matches(json, "\"name\"\\s*:\\s*\"([^\"]+)\"[^\\}]*?\"browser_download_url\"\\s*:\\s*\"([^\"]+)\"");
            foreach (Match m in matches)
            {
                if (m.Success && m.Groups.Count >= 3)
                {
                    string name = m.Groups[1].Value;
                    string url = m.Groups[2].Value;
                    if (!dict.ContainsKey(name))
                    {
                        dict.Add(name, url);
                    }
                }
            }
            return dict;
        }

        private static bool DownloadFileWithProgress(string url, string destinationPath)
        {
            try
            {
                using (var client = new WebClient())
                {
                    client.Headers.Add("User-Agent", "BVDKKH-Remote-Installer/1.0");

                    if (!isSilentMode)
                    {
                        int lastPercent = -1;
                        client.DownloadProgressChanged += (s, e) =>
                        {
                            if (e.ProgressPercentage != lastPercent)
                            {
                                lastPercent = e.ProgressPercentage;
                                double mbReceived = e.BytesReceived / 1024.0 / 1024.0;
                                double mbTotal = e.TotalBytesToReceive / 1024.0 / 1024.0;
                                Console.Write(string.Format("\r    -> Tiến trình tải: [{0}%] ({1:F1} MB / {2:F1} MB)    ",
                                    lastPercent, mbReceived, mbTotal));
                            }
                        };
                    }

                    client.DownloadFile(new Uri(url), destinationPath);
                    if (!isSilentMode)
                    {
                        Console.WriteLine();
                    }
                    return true;
                }
            }
            catch (Exception ex)
            {
                Log("\n[X] Lỗi tải file: " + ex.Message);
                return false;
            }
        }

        private static int RunSilentInstall(string installerPath)
        {
            try
            {
                var startInfo = new ProcessStartInfo
                {
                    FileName = installerPath,
                    Arguments = "--silent-install",
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                using (var proc = Process.Start(startInfo))
                {
                    proc.WaitForExit();
                    return proc.ExitCode;
                }
            }
            catch (Exception ex)
            {
                Log("[X] Lỗi khi thực thi cài đặt ngầm: " + ex.Message);
                return -1;
            }
        }

        private static void Log(string message)
        {
            if (!isSilentMode)
            {
                Console.WriteLine(message);
            }
            try
            {
                string line = string.Format("[{0:yyyy-MM-dd HH:mm:ss}] {1}{2}", DateTime.Now, message, Environment.NewLine);
                File.AppendAllText(logPath, line, Encoding.UTF8);
            }
            catch { }
        }
    }
}
