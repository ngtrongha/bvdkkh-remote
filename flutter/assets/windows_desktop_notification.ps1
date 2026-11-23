# Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
# Project: BVĐKKH - Remote
# Author: Nguyễn Trọng Hà

$ErrorActionPreference = 'Stop'
$payload = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String($env:BVDKKH_DESKTOP_NOTIFICATION)
) | ConvertFrom-Json

Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Media;
using System.Windows.Forms;

public sealed class HospitalNotification : Form {
    protected override bool ShowWithoutActivation { get { return true; } }

    private static GraphicsPath Outline(int width, int height, int diameter) {
        var path = new GraphicsPath();
        int right = width - 1;
        int bottom = height - 1;
        path.AddArc(0, 0, diameter, diameter, 180, 90);
        path.AddArc(right - diameter, 0, diameter, diameter, 270, 90);
        path.AddArc(right - diameter, bottom - diameter, diameter, diameter, 0, 90);
        path.AddArc(0, bottom - diameter, diameter, diameter, 90, 90);
        path.CloseFigure();
        return path;
    }

    public static void Display(string title, string body, string logoPath, bool dark, bool sound) {
        Application.EnableVisualStyles();
        var area = Screen.FromPoint(Cursor.Position).WorkingArea;
        int width = Math.Min(424, area.Width - 32);
        bool highContrast = SystemInformation.HighContrast;
        var surface = highContrast ? SystemColors.Window : ColorTranslator.FromHtml(dark ? "#0F172A" : "#FFFFFF");
        var ink = highContrast ? SystemColors.WindowText : ColorTranslator.FromHtml(dark ? "#F8FAFC" : "#0F172A");
        var muted = highContrast ? ink : ColorTranslator.FromHtml(dark ? "#CBD5E1" : "#475569");
        var line = highContrast ? ink : ColorTranslator.FromHtml(dark ? "#334155" : "#E2E8F0");
        var accent = highContrast ? SystemColors.Highlight : ColorTranslator.FromHtml("#0D9488");
        var action = highContrast ? SystemColors.Highlight : ColorTranslator.FromHtml("#0F766E");
        var actionText = highContrast ? SystemColors.HighlightText : Color.White;

        using (var form = new HospitalNotification())
        using (var font = new Font("Segoe UI", 10.5f))
        using (var headline = new Font("Segoe UI Semibold", 14f))
        using (var logo = new Bitmap(logoPath))
        using (var timer = new Timer { Interval = 30000 }) {
            const int inset = 20;
            const int logoSize = 56;
            int headingX = inset + logoSize + 14;
            int headingWidth = width - headingX - inset;
            int headingHeight = TextRenderer.MeasureText(title, headline, new Size(headingWidth, 0),
                TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix).Height;
            int bodyTop = Math.Max(24 + logoSize, 44 + headingHeight) + 14;
            int bodyWidth = width - inset * 2;
            int textHeight = TextRenderer.MeasureText(body, font, new Size(bodyWidth - 20, 0),
                TextFormatFlags.WordBreak | TextFormatFlags.TextBoxControl | TextFormatFlags.NoPrefix).Height;
            int bodyHeight = Math.Min(Math.Max(textHeight + 9, 35), Math.Max(35, Math.Min(168, area.Height - bodyTop - 92)));

            form.Text = title;
            form.AccessibleName = "BV\u0110KKH Remote";
            form.AutoScaleMode = AutoScaleMode.None;
            form.Font = font;
            form.FormBorderStyle = FormBorderStyle.None;
            form.BackColor = surface;
            form.StartPosition = FormStartPosition.Manual;
            form.ShowInTaskbar = false;
            form.TopMost = true;
            form.ClientSize = new Size(width, bodyTop + bodyHeight + 64);
            form.Location = new Point(area.Right - width - 16, Math.Max(area.Top + 16, area.Bottom - form.Height - 16));

            form.Controls.Add(new PictureBox {
                Bounds = new Rectangle(inset, 24, logoSize, logoSize),
                Image = logo, SizeMode = PictureBoxSizeMode.Zoom,
                AccessibleName = "B\u1ec7nh vi\u1ec7n \u0110a khoa t\u1ec9nh Kh\u00e1nh H\u00f2a",
            });
            form.Controls.Add(new Label {
                Text = "BV\u0110KKH Remote", ForeColor = muted, UseMnemonic = false,
                Bounds = new Rectangle(headingX, 22, headingWidth, 21),
            });
            form.Controls.Add(new Label {
                Text = title, Font = headline, ForeColor = ink, UseMnemonic = false,
                Bounds = new Rectangle(headingX, 44, headingWidth, headingHeight + 3),
            });
            Control content = textHeight + 9 > bodyHeight
                ? (Control)new TextBox {
                    Text = body.Replace("\r\n", "\n").Replace("\n", "\r\n"),
                    BorderStyle = BorderStyle.None, Multiline = true, ReadOnly = true,
                    WordWrap = true, ScrollBars = ScrollBars.Vertical,
                    AccessibleName = "N\u1ed9i dung th\u00f4ng b\u00e1o",
                }
                : new Label { Text = body, UseMnemonic = false };
            content.Bounds = new Rectangle(inset, bodyTop, bodyWidth, bodyHeight);
            content.BackColor = surface;
            content.ForeColor = muted;
            form.Controls.Add(content);
            var close = new Button {
                Text = "\u0110\u00f3ng", FlatStyle = FlatStyle.Flat,
                BackColor = action, ForeColor = actionText,
                Bounds = new Rectangle(width - inset - 92, form.Height - 51, 92, 35),
                DialogResult = DialogResult.Cancel,
            };
            close.FlatAppearance.BorderSize = 0;
            using (var shape = Outline(close.Width, close.Height, 16)) close.Region = new Region(shape);
            close.Click += delegate { form.Close(); };
            form.CancelButton = close;
            form.Controls.Add(close);
            form.ActiveControl = close;
            form.Controls.Add(new Panel { BackColor = accent, Bounds = new Rectangle(0, 0, width, 4) });

            using (var outline = Outline(form.ClientSize.Width, form.ClientSize.Height, 24)) {
                form.Region = new Region(outline);
                form.Paint += delegate(object sender, PaintEventArgs e) {
                    e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
                    using (var pen = new Pen(line, 2)) e.Graphics.DrawPath(pen, outline);
                };
                timer.Tick += delegate { form.Close(); };
                form.Shown += delegate {
                    if (sound) SystemSounds.Asterisk.Play();
                    timer.Start();
                };
                Application.Run(form);
            }
        }
    }
}
'@

[HospitalNotification]::Display($payload.title, $payload.body, $payload.logo, $payload.dark, $payload.sound)
