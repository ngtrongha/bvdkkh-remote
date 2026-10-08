// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remoter
// Author: Nguyễn Trọng Hà
// Description: Trình cài đặt tự động (GUI + Silent Bootstrapper) cho BVĐKKH - Remote
//              Tự động nhận diện Windows (Win7/8 vs Win10/11, x64/x86/ARM64),
//              tải bản mới nhất từ GitHub Releases và cài đặt ngầm vào hệ thống.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Net;
using System.Runtime.InteropServices;
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
        private const string GITHUB_API_URL = "https://api.github.com/repos/ngtrongha/bvdkkh-remote-release/releases/latest";
        private const string LOG_FILE = "bvdkkh_installer.log";

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

        [STAThread]
        static int Main(string[] args)
        {
            ConfigureSecurityProtocol();

            bool isSilent = false;
            bool isCheckOnly = false;

            foreach (var arg in args)
            {
                string a = arg.Trim().ToLowerInvariant();
                if (a == "/s" || a == "-s" || a == "/silent" || a == "--silent" || a == "/quiet" || a == "/q")
                {
                    isSilent = true;
                }
                else if (a == "--check" || a == "/check" || a == "--test" || a == "/test")
                {
                    isCheckOnly = true;
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
                }
                catch
                {
                    // Người dùng bấm No hoặc môi trường không hỗ trợ elevation
                }
            }

            // 2. Chế độ kiểm tra (CLI / Check only)
            if (isCheckOnly)
            {
                var info = DetectEnvironment();
                string releaseJson = FetchLatestReleaseJson();
                string tag = ExtractTagName(releaseJson);
                var asset = ResolveMatchingAsset(info, releaseJson, tag);
                Console.WriteLine("Thiết bị: " + info.OsName + " (" + info.Arch + ")");
                Console.WriteLine("Phiên bản: " + tag);
                Console.WriteLine("Gói tải: " + asset.Key);
                Console.WriteLine("Link: " + asset.Value);
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

        public static string FetchLatestReleaseJson()
        {
            try
            {
                using (var client = new WebClient())
                {
                    client.Encoding = Encoding.UTF8;
                    client.Headers.Add("User-Agent", "BVDKKH-Remote-Installer/1.0");
                    return client.DownloadString(GITHUB_API_URL);
                }
            }
            catch
            {
                return "";
            }
        }

        public static string ExtractTagName(string json)
        {
            if (string.IsNullOrEmpty(json)) return "v1.5.16";
            var match = Regex.Match(json, "\"tag_name\"\\s*:\\s*\"([^\"]+)\"");
            return match.Success ? match.Groups[1].Value : "v1.5.16";
        }

        public static KeyValuePair<string, string> ResolveMatchingAsset(DeviceInfo info, string json, string tagName)
        {
            if (!string.IsNullOrEmpty(json))
            {
                var matches = Regex.Matches(json, "\"name\"\\s*:\\s*\"([^\"]+)\"[^\\}]*?\"browser_download_url\"\\s*:\\s*\"([^\"]+)\"");
                foreach (Match m in matches)
                {
                    if (m.Success && m.Groups.Count >= 3)
                    {
                        string name = m.Groups[1].Value;
                        string url = m.Groups[2].Value;
                        string lower = name.ToLowerInvariant();

                        if (!lower.EndsWith(".exe") || lower.EndsWith(".apk") || lower.Contains("setup"))
                            continue;

                        if (info.Arch == "ARM64" && lower.Contains("aarch64"))
                            return new KeyValuePair<string, string>(name, url);

                        if (info.Arch == "x86" && lower.Contains("x86-sciter"))
                            return new KeyValuePair<string, string>(name, url);

                        if (info.IsWin10OrLater && info.Arch == "x64")
                        {
                            if (lower.Contains("x86_64") && !lower.Contains("win7"))
                                return new KeyValuePair<string, string>(name, url);
                        }
                        else if (!info.IsWin10OrLater && info.Arch == "x64")
                        {
                            if (lower.Contains("win7") && lower.Contains("x86_64"))
                                return new KeyValuePair<string, string>(name, url);
                        }
                    }
                }
            }

            string tag = !string.IsNullOrEmpty(tagName) ? tagName : "v1.5.16";
            string ver = tag.TrimStart('v');
            string fallbackFile = "";
            if (info.Arch == "x86")
                fallbackFile = string.Format("rustdesk-{0}-x86-sciter.exe", ver);
            else if (info.IsWin10OrLater)
                fallbackFile = string.Format("rustdesk-{0}-x86_64.exe", ver);
            else
                fallbackFile = string.Format("rustdesk-{0}-win7-x86_64.exe", ver);

            string fallbackUrl = string.Format("https://github.com/ngtrongha/bvdkkh-remote-release/releases/download/{0}/{1}", tag, fallbackFile);
            return new KeyValuePair<string, string>(fallbackFile, fallbackUrl);
        }

        private static int RunSilentBackgroundInstall()
        {
            var info = DetectEnvironment();
            string json = FetchLatestReleaseJson();
            string tag = ExtractTagName(json);
            var asset = ResolveMatchingAsset(info, json, tag);

            string tempPath = Path.Combine(Path.GetTempPath(), asset.Key);
            try
            {
                using (var client = new WebClient())
                {
                    client.Headers.Add("User-Agent", "BVDKKH-Remote-Installer/1.0");
                    client.DownloadFile(new Uri(asset.Value), tempPath);
                }

                if (!File.Exists(tempPath)) return 1;

                var psi = new ProcessStartInfo
                {
                    FileName = tempPath,
                    Arguments = "--silent-install",
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                using (var proc = Process.Start(psi))
                {
                    proc.WaitForExit();
                    try { File.Delete(tempPath); } catch { }
                    return proc.ExitCode;
                }
            }
            catch (Exception ex)
            {
                string log = Path.Combine(Path.GetTempPath(), LOG_FILE);
                File.AppendAllText(log, "[" + DateTime.Now + "] Lỗi cài đặt ngầm: " + ex.Message + Environment.NewLine);
                return -1;
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
                Text = "Đang kiểm tra phiên bản mới nhất từ máy chủ...",
                Font = new Font("Segoe UI", 10.5f, FontStyle.Bold),
                ForeColor = Color.FromArgb(15, 23, 42),
                Location = new Point(24, 150),
                Size = new Size(492, 26)
            };
            this.Controls.Add(lblStatus);

            lblDetail = new Label
            {
                Text = "Vui lòng giữ kết nối Internet trong quá trình thiết lập.",
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
                Text = "Tự động tải gói tối ưu cho thiết bị và cấu hình nền bảo mật.",
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

                    // Bước 2: Gọi GitHub API lấy bản mới nhất
                    this.Invoke(new Action(() =>
                    {
                        lblStatus.Text = "Đang kiểm tra phiên bản mới nhất từ máy chủ...";
                        lblDetail.Text = "Đang kết nối kho phát hành chính thức...";
                        progressBar.Value = 15;
                    }));

                    string json = Program.FetchLatestReleaseJson();
                    string tag = Program.ExtractTagName(json);
                    var asset = Program.ResolveMatchingAsset(info, json, tag);

                    this.Invoke(new Action(() =>
                    {
                        lblBadge.Text = string.Format("🖥 {0} ({1})   •   Phiên bản: {2}", info.OsName, info.Arch, tag);
                        lblStatus.Text = "Đang tải gói cài đặt: " + asset.Key;
                        lblDetail.Text = "Chuẩn bị tải dữ liệu...";
                        progressBar.Value = 25;
                    }));

                    // Bước 3: Tải file về thư mục tạm
                    string tempPath = Path.Combine(Path.GetTempPath(), asset.Key);
                    downloadedFile = tempPath;

                    using (webClient = new WebClient())
                    {
                        webClient.Headers.Add("User-Agent", "BVDKKH-Remote-Installer/1.0");
                        webClient.DownloadProgressChanged += (s, e) =>
                        {
                            this.BeginInvoke(new Action(() =>
                            {
                                int val = 25 + (int)(e.ProgressPercentage * 0.55); // Từ 25% -> 80%
                                progressBar.Value = Math.Min(val, 80);
                                double mbRec = e.BytesReceived / 1024.0 / 1024.0;
                                double mbTotal = e.TotalBytesToReceive / 1024.0 / 1024.0;
                                lblDetail.Text = string.Format("Đã tải: {0:F1} MB / {1:F1} MB ({2}%)", mbRec, mbTotal, e.ProgressPercentage);
                            }));
                        };

                        webClient.DownloadFile(new Uri(asset.Value), tempPath);
                    }

                    // Bước 4: Thực thi cài đặt ngầm
                    this.Invoke(new Action(() =>
                    {
                        lblStatus.Text = "Đang tiến hành cài đặt ngầm vào hệ thống...";
                        lblDetail.Text = "Đang tạo dịch vụ nền, phím tắt và hoàn tất cấu hình...";
                        progressBar.Value = 88;
                    }));

                    var psi = new ProcessStartInfo
                    {
                        FileName = tempPath,
                        Arguments = "--silent-install",
                        UseShellExecute = false,
                        CreateNoWindow = true
                    };

                    using (var proc = Process.Start(psi))
                    {
                        proc.WaitForExit();
                        ExitCode = proc.ExitCode;
                    }

                    // Dọn dẹp file tạm
                    try { if (File.Exists(tempPath)) File.Delete(tempPath); } catch { }

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
                    foreach (var p in possiblePaths)
                    {
                        if (File.Exists(p))
                        {
                            Process.Start(p);
                            launched = true;
                            break;
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
