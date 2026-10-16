// VertexColorWriter UI v1.4.0. Shared by MAXScript and the off-host UI smoke test.
// .NET Framework-compatible C#; no third-party dependencies.
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Globalization;
using System.Collections.Generic;
using System.Windows.Forms;

namespace MaxZJTools.VertexColorWriter
{
    public sealed class WriterPanel : UserControl
    {
        public event EventHandler BakeRequested;
        public event EventHandler SelectionRefreshRequested;
        public event EventHandler HeightDisplayChanged;
        private readonly RadioButton heightMode = new RadioButton();
        private readonly RadioButton solidMode = new RadioButton();
        private readonly RadioButton textureMode = new RadioButton();
        private readonly ComboBox writeScope = new ComboBox();
        private readonly Label vertexReadout = new Label();
        private int selectedVertexCount, totalVertexCount, otherCount;
        private bool vertexContextValid;
        private string vertexReason = "请进入顶点模式并选点";
        private readonly NumericUpDown uvChannel = Number(1, 99, 1, 0);
        private readonly ComboBox texturePurpose = new ComboBox();
        private readonly ComboBox textureFilter = new ComboBox();
        private readonly ComboBox textureWrap = new ComboBox();
        private readonly Label texturePath = new Label();
        private readonly Label textureInfo = new Label();
        private readonly TexturePreview texturePreview = new TexturePreview();
        private readonly Panel valueSettings = new Panel();
        private Control textureSettings, gradientCard, textureCard;
        private TextureSource texture;
        private bool ready;
        private readonly CheckBox[] channels = new CheckBox[4];
        private readonly ComboBox origin = new ComboBox();
        private readonly NumericUpDown start = Number(-1000000, 1000000, 0, 3);
        private readonly NumericUpDown span = Number(0.001m, 1000000, 1, 3);
        private readonly NumericUpDown lowAlpha = Number(0, 1, 0, 2);
        private readonly NumericUpDown highAlpha = Number(0, 1, 1, 2);
        private readonly Button lowColor = new Button();
        private readonly Button highColor = new Button();
        private readonly Label lowTitle = new Label();
        private readonly CheckBox clamp = new CheckBox();
        private readonly CheckBox viewport = new CheckBox();
        private readonly CheckBox heightRuler = new CheckBox();
        private readonly Label measuredHeight = new Label();
        private readonly ToolTip measurementTip = new ToolTip();
        private readonly Label selection = new Label();
        private readonly Label status = new Label();
        private readonly Button bake = new Button();
        private readonly Button details = new Button();
        private readonly GradientPreview preview = new GradientPreview();
        private readonly Timer selectionTimer = new Timer();
        private readonly Panel options = new Panel();
        private readonly Font bodyFont = new Font("Microsoft YaHei UI", 12f);
        private readonly Font headingFont = new Font("Microsoft YaHei UI", 12f, FontStyle.Bold);
        private readonly List<Image> ownedIcons = new List<Image>();
        private Image loadedToolIcon;
        public bool HasToolIcon { get { return loadedToolIcon != null; } }
        private bool busy;
        private int modelCount;
        private string lastReport = "";
        private Color bottom = Color.Black;
        private Color top = Color.White;
        private readonly Color background = Color.FromArgb(32, 34, 38);
        private readonly Color cardColor = Color.FromArgb(43, 46, 51);
        private readonly Color foreground = Color.FromArgb(232, 234, 238);

        public WriterPanel()
        {
            Font = bodyFont;
            BackColor = background;
            ForeColor = foreground;
            AutoScaleMode = AutoScaleMode.Dpi;
            AutoScaleDimensions = new SizeF(96, 96);
            Size = new Size(860, 808);
            MinimumSize = new Size(820, 768);
            Dock = DockStyle.Fill;
            var root = new TableLayoutPanel();
            root.Dock = DockStyle.Fill;
            root.Padding = new Padding(16);
            root.ColumnCount = 1;
            root.RowCount = 6;
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute, 80));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute, 34));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute, 48));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute, 52));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute, 32));
            Controls.Add(root);

            var columns = new TableLayoutPanel();
            columns.Dock = DockStyle.Fill;
            columns.Margin = new Padding(0);
            columns.ColumnCount = 2;
            columns.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 64));
            columns.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 36));
            root.Controls.Add(columns, 0, 0);
            options.Dock = DockStyle.Fill;
            options.Margin = new Padding(0, 0, 12, 0);
            columns.Controls.Add(options, 0, 0);
            var left = new TableLayoutPanel();
            left.Dock = DockStyle.Fill;
            left.Margin = new Padding(0);
            left.RowCount = 4;
            left.ColumnCount = 1;
            left.RowStyles.Add(new RowStyle(SizeType.Absolute, 52));
            left.RowStyles.Add(new RowStyle(SizeType.Absolute, 48));
            left.RowStyles.Add(new RowStyle(SizeType.Absolute, 82));
            left.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            options.Controls.Add(left);

            var modes = new FlowLayoutPanel();
            modes.Dock = DockStyle.Fill;
            modes.Margin = new Padding(0);
            heightMode.Text = "高度渐变";
            solidMode.Text = "固定颜色";
            textureMode.Text = "贴图写入";
            heightMode.Image = Glyph("height");
            solidMode.Image = Glyph("color");
            textureMode.Image = Glyph("texture");
            foreach (RadioButton radio in new RadioButton[] { heightMode, solidMode, textureMode })
            {
                radio.AutoSize = true;
                radio.TextImageRelation = TextImageRelation.ImageBeforeText;
                radio.ImageAlign = ContentAlignment.MiddleLeft;
                radio.Margin = new Padding(4, 10, 10, 6);
                modes.Controls.Add(radio);
                radio.CheckedChanged += Changed;
            }
            heightMode.Checked = true;
            left.Controls.Add(modes, 0, 0);

            var scopeRow = new TableLayoutPanel();
            scopeRow.Dock = DockStyle.Fill;
            scopeRow.Margin = new Padding(4, 0, 0, 4);
            scopeRow.ColumnCount = 3;
            scopeRow.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 86));
            scopeRow.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 136));
            scopeRow.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            var scopeTitle = new Label();
            scopeTitle.Text = "写入范围";
            scopeTitle.Dock = DockStyle.Fill;
            scopeTitle.TextAlign = ContentAlignment.MiddleLeft;
            scopeRow.Controls.Add(scopeTitle, 0, 0);
            writeScope.DropDownStyle = ComboBoxStyle.DropDownList;
            writeScope.Items.AddRange(new object[] { "整个模型", "选中顶点" });
            writeScope.Dock = DockStyle.Top;
            writeScope.Margin = new Padding(0, 6, 8, 0);
            writeScope.SelectedIndex = 0;
            writeScope.SelectedIndexChanged += delegate
            {
                Changed(this, EventArgs.Empty);
                if (ready && SelectionRefreshRequested != null) SelectionRefreshRequested(this, EventArgs.Empty);
            };
            scopeRow.Controls.Add(writeScope, 1, 0);
            vertexReadout.Dock = DockStyle.Fill;
            vertexReadout.TextAlign = ContentAlignment.MiddleLeft;
            vertexReadout.AutoEllipsis = true;
            scopeRow.Controls.Add(vertexReadout, 2, 0);
            measurementTip.SetToolTip(writeScope, "选中顶点：单选模型，进入顶点模式后选点。\n固定颜色、高度渐变和贴图写入都支持；只写硬选择，不使用软选择权重。");
            left.Controls.Add(scopeRow, 0, 1);

            var channelFlow = new FlowLayoutPanel();
            channelFlow.Dock = DockStyle.Fill;
            channelFlow.WrapContents = false;
            for (int i = 0; i < 4; i++)
            {
                channels[i] = new CheckBox();
                channels[i].Text = "RGBA"[i].ToString();
                channels[i].AutoSize = true;
                channels[i].Margin = new Padding(0, 4, 30, 0);
                channels[i].Checked = i == 0;
                channels[i].CheckedChanged += Changed;
                channelFlow.Controls.Add(channels[i]);
            }
            left.Controls.Add(Card("写入通道 · 未勾选的通道保留", channelFlow, "channels"), 0, 2);

            var parameterHost = new Panel();
            parameterHost.Dock = DockStyle.Fill;
            parameterHost.Margin = new Padding(0);
            left.Controls.Add(parameterHost, 0, 3);
            valueSettings.Dock = DockStyle.Fill;
            parameterHost.Controls.Add(valueSettings);
            var valueRows = new TableLayoutPanel();
            valueRows.Dock = DockStyle.Fill;
            valueRows.Margin = new Padding(0);
            valueRows.RowCount = 2;
            valueRows.ColumnCount = 1;
            valueRows.RowStyles.Add(new RowStyle(SizeType.Absolute, 142));
            valueRows.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            valueSettings.Controls.Add(valueRows);

            var colors = new TableLayoutPanel();
            colors.Dock = DockStyle.Fill;
            colors.ColumnCount = 4;
            colors.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 94));
            colors.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            colors.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 68));
            colors.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 86));
            colors.RowCount = 2;
            colors.RowStyles.Add(new RowStyle(SizeType.Percent, 50));
            colors.RowStyles.Add(new RowStyle(SizeType.Percent, 50));
            ConfigureLabel(lowTitle, "底部颜色");
            colors.Controls.Add(lowTitle, 0, 0);
            colors.Controls.Add(Label("顶部颜色"), 0, 1);
            ConfigureColorButton(lowColor);
            ConfigureColorButton(highColor);
            colors.Controls.Add(lowColor, 1, 0);
            colors.Controls.Add(highColor, 1, 1);
            colors.Controls.Add(Label("Alpha"), 2, 0);
            colors.Controls.Add(Label("Alpha"), 2, 1);
            colors.Controls.Add(lowAlpha, 3, 0);
            colors.Controls.Add(highAlpha, 3, 1);
            lowColor.Click += delegate { PickColor(false); };
            highColor.Click += delegate { PickColor(true); };
            lowAlpha.ValueChanged += Changed;
            highAlpha.ValueChanged += Changed;
            valueRows.Controls.Add(Card("颜色与透明度", colors, "color"), 0, 0);

            var mapping = new TableLayoutPanel();
            mapping.Dock = DockStyle.Fill;
            mapping.ColumnCount = 2;
            mapping.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 47));
            mapping.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 53));
            mapping.RowCount = 4;
            for (int i = 0; i < 4; i++) mapping.RowStyles.Add(new RowStyle(SizeType.Percent, 25));
            origin.DropDownStyle = ComboBoxStyle.DropDownList;
            origin.Items.AddRange(new object[] { "同一世界高度", "距各自底部高度" });
            origin.SelectedIndex = 0;
            origin.Dock = DockStyle.Fill;
            origin.SelectedIndexChanged += Changed;
            mapping.Controls.Add(Label("对齐方式"), 0, 0);
            mapping.Controls.Add(origin, 1, 0);
            mapping.Controls.Add(Label("起始高度（米）"), 0, 1);
            mapping.Controls.Add(start, 1, 1);
            mapping.Controls.Add(Label("映射高度（米）"), 0, 2);
            mapping.Controls.Add(span, 1, 2);
            clamp.Text = "范围外使用两端颜色";
            clamp.Checked = true;
            clamp.Dock = DockStyle.Fill;
            clamp.CheckedChanged += Changed;
            mapping.Controls.Add(clamp, 0, 3);
            mapping.SetColumnSpan(clamp, 2);
            start.ValueChanged += Changed;
            span.ValueChanged += Changed;
            valueRows.Controls.Add(Card("高度范围", mapping, "height"), 0, 1);
            textureSettings = BuildTextureSettings();
            parameterHost.Controls.Add(textureSettings);

            preview.Dock = DockStyle.Fill;
            preview.Font = bodyFont;
            preview.BackColor = cardColor;
            preview.ForeColor = foreground;
            var previewHost = new Panel();
            previewHost.Dock = DockStyle.Fill;
            previewHost.Margin = new Padding(0);
            columns.Controls.Add(previewHost, 1, 0);
            gradientCard = Card("纵向映射预览", preview, "height");
            texturePreview.Font = bodyFont;
            texturePreview.ForeColor = foreground;
            textureCard = Card("贴图原图预览", texturePreview, "texture");
            previewHost.Controls.Add(gradientCard);
            previewHost.Controls.Add(textureCard);

            var measurementRow = new TableLayoutPanel();
            measurementRow.Dock = DockStyle.Fill;
            measurementRow.ColumnCount = 2;
            measurementRow.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            measurementRow.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 230));
            ConfigureLabel(measuredHeight, "请选择一个模型查看高度");
            measurementRow.Controls.Add(measuredHeight, 0, 0);
            heightRuler.Text = "视口显示高度标尺";
            heightRuler.Checked = true;
            heightRuler.Dock = DockStyle.Fill;
            heightRuler.CheckedChanged += delegate { if (HeightDisplayChanged != null) HeightDisplayChanged(this, EventArgs.Empty); };
            measurementRow.Controls.Add(heightRuler, 1, 0);
            root.Controls.Add(Card("当前模型高度 · 世界 Z（只读）", measurementRow, "ruler"), 0, 1);

            var selectionRow = new TableLayoutPanel();
            selectionRow.Dock = DockStyle.Fill;
            selectionRow.ColumnCount = 2;
            selectionRow.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
            selectionRow.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
            ConfigureLabel(selection, "请在场景中选择模型");
            selectionRow.Controls.Add(selection, 0, 0);
            viewport.Text = "完成后显示顶点色 RGB";
            viewport.Dock = DockStyle.Fill;
            selectionRow.Controls.Add(viewport, 1, 0);
            root.Controls.Add(selectionRow, 0, 2);

            var statusRow = new TableLayoutPanel();
            statusRow.Dock = DockStyle.Fill;
            statusRow.ColumnCount = 2;
            statusRow.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            statusRow.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 142));
            ConfigureLabel(status, "设置参数后点击写入。");
            statusRow.Controls.Add(status, 0, 0);
            details.Text = "处理明细";
            details.Dock = DockStyle.Fill;
            details.Enabled = false;
            StyleButton(details);
            ButtonGlyph(details, "details");
            details.Click += delegate { ShowReport(); };
            statusRow.Controls.Add(details, 1, 0);
            root.Controls.Add(statusRow, 0, 3);
            bake.Dock = DockStyle.Fill;
            bake.Text = "请先选择模型";
            bake.Enabled = false;
            bake.Font = headingFont;
            StyleButton(bake);
            ButtonGlyph(bake, "write");
            bake.TextImageRelation = TextImageRelation.Overlay;
            bake.Click += delegate { if (BakeRequested != null) BakeRequested(this, EventArgs.Empty); };
            root.Controls.Add(bake, 0, 4);
            var footer = Label("只影响勾选的通道 · 支持 Ctrl+Z · 修改模型后需重新写入");
            footer.TextAlign = ContentAlignment.MiddleCenter;
            root.Controls.Add(footer, 0, 5);
            selectionTimer.Interval = 500;
            selectionTimer.Tick += delegate { if (!busy && SelectionRefreshRequested != null) SelectionRefreshRequested(this, EventArgs.Empty); };
            ready = true;
            RefreshOptions();
        }

        private Control BuildTextureSettings()
        {
            var rows = new TableLayoutPanel();
            rows.Dock = DockStyle.Fill;
            rows.ColumnCount = 1;
            rows.RowCount = 5;
            rows.RowStyles.Add(new RowStyle(SizeType.Absolute, 36));
            rows.RowStyles.Add(new RowStyle(SizeType.Absolute, 34));
            rows.RowStyles.Add(new RowStyle(SizeType.Absolute, 26));
            rows.RowStyles.Add(new RowStyle(SizeType.Absolute, 144));
            rows.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            var buttons = new TableLayoutPanel();
            buttons.Dock = DockStyle.Fill;
            buttons.Margin = new Padding(0);
            buttons.ColumnCount = 2;
            buttons.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 65));
            buttons.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 35));
            var choose = new Button();
            choose.Text = "选择贴图…";
            choose.Dock = DockStyle.Fill;
            StyleButton(choose);
            ButtonGlyph(choose, "folder");
            choose.Click += delegate
            {
                using (var dialog = new OpenFileDialog())
                {
                    dialog.Title = "选择要写入顶点色的图片";
                    dialog.Filter = "贴图 (PNG / JPG / BMP / TGA)|*.png;*.jpg;*.jpeg;*.bmp;*.tga";
                    if (dialog.ShowDialog(this) == DialogResult.OK) LoadTextureFile(dialog.FileName);
                }
            };
            var reload = new Button();
            reload.Text = "重新读取";
            reload.Dock = DockStyle.Fill;
            StyleButton(reload);
            ButtonGlyph(reload, "reload");
            reload.Click += delegate { if (texturePath.Tag != null) LoadTextureFile((string)texturePath.Tag); };
            buttons.Controls.Add(choose, 0, 0);
            buttons.Controls.Add(reload, 1, 0);
            rows.Controls.Add(buttons, 0, 0);
            ConfigureLabel(texturePath, "尚未选择贴图");
            ConfigureLabel(textureInfo, "支持 PNG / JPG / BMP / TGA");
            rows.Controls.Add(texturePath, 0, 1);
            rows.Controls.Add(textureInfo, 0, 2);
            var fields = new TableLayoutPanel();
            fields.Dock = DockStyle.Fill;
            fields.Margin = new Padding(0);
            fields.ColumnCount = 2;
            fields.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 32));
            fields.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 68));
            fields.RowCount = 4;
            for (int i = 0; i < 4; i++) fields.RowStyles.Add(new RowStyle(SizeType.Percent, 25));
            uvChannel.Increment = 1;
            uvChannel.ValueChanged += Changed;
            SetupChoice(texturePurpose, new object[] { "颜色 · sRGB 转线性", "遮罩 · 保持原始数值" });
            SetupChoice(textureFilter, new object[] { "双线性 · 平滑过渡", "最近点 · 逐像素取值" });
            SetupChoice(textureWrap, new object[] { "截取 · 使用边缘颜色", "平铺 · 重复贴图" });
            fields.Controls.Add(Label("UV 通道"), 0, 0);
            fields.Controls.Add(uvChannel, 1, 0);
            fields.Controls.Add(Label("贴图用途"), 0, 1);
            fields.Controls.Add(texturePurpose, 1, 1);
            fields.Controls.Add(Label("采样方式"), 0, 2);
            fields.Controls.Add(textureFilter, 1, 2);
            fields.Controls.Add(Label("UV 越界"), 0, 3);
            fields.Controls.Add(textureWrap, 1, 3);
            rows.Controls.Add(fields, 0, 3);
            rows.Controls.Add(Label("完整颜色请勾选 RGB；Alpha 仅在勾选 A 时写入。"), 0, 4);
            return Card("图片与 UV", rows, "texture");
        }
        private void SetupChoice(ComboBox control, object[] values)
        {
            control.DropDownStyle = ComboBoxStyle.DropDownList;
            control.Dock = DockStyle.Fill;
            control.Items.AddRange(values);
            control.SelectedIndex = 0;
            control.SelectedIndexChanged += Changed;
        }
        public bool LoadTextureFile(string path)
        {
            texture = null;
            texturePreview.SetImage(null);
            texturePath.Tag = path;
            texturePath.Text = System.IO.Path.GetFileName(path);
            measurementTip.SetToolTip(texturePath, path);
            try
            {
                var loaded = TextureSource.Load(path);
                texturePreview.SetImage(loaded.CreateThumbnail());
                texture = loaded;
                textureInfo.Text = loaded.Width + " × " + loaded.Height + " 像素 · 已读取";
                status.Text = "贴图已读取。选择 UV 通道与写入通道。";
            }
            catch (Exception error)
            {
                textureInfo.Text = "读取失败，请检查文件或格式";
                SetResult("贴图读取失败，请查看处理明细。", path + "\n" + error.Message);
            }
            RefreshOptions();
            return texture != null;
        }

        private Image Glyph(string name)
        {
            Image value = PanelGlyphs.Create(name, 24);
            ownedIcons.Add(value);
            return value;
        }
        private void ButtonGlyph(Button button, string name)
        {
            button.Image = Glyph(name);
            button.ImageAlign = ContentAlignment.MiddleLeft;
            button.Padding = new Padding(6, 0, 6, 0);
            button.TextImageRelation = TextImageRelation.ImageBeforeText;
        }
        // Optional appearance resource: missing/broken icons must never disable the tool.
        public bool LoadToolIcon(string iconDirectory)
        {
            try
            {
                string path = System.IO.Path.Combine(iconDirectory, "Dark", "MaxZJTools", "VertexColorWriter_32.png");
                Image replacement;
                using (var source = Image.FromFile(path)) replacement = new Bitmap(source);
                Image previous = loadedToolIcon;
                loadedToolIcon = replacement;
                bake.Image = replacement;
                if (previous != null) previous.Dispose();
                return true;
            }
            catch (Exception) { return false; } // The built-in write glyph remains usable.
        }
        private Panel Card(string title, Control content, string glyph)
        {
            var panel = new Panel();
            panel.Dock = DockStyle.Fill;
            panel.BackColor = cardColor;
            panel.Margin = new Padding(0, 0, 0, 10);
            panel.Padding = new Padding(12, 6, 12, 10);
            var heading = Label(title);
            heading.Font = headingFont;
            var headingRow = new Panel();
            headingRow.Dock = DockStyle.Top;
            headingRow.Height = 30;
            var symbol = new PictureBox();
            symbol.Image = Glyph(glyph);
            symbol.SizeMode = PictureBoxSizeMode.CenterImage;
            symbol.Width = 32;
            symbol.Dock = DockStyle.Left;
            headingRow.Controls.Add(heading);
            headingRow.Controls.Add(symbol);
            content.Dock = DockStyle.Fill;
            panel.Controls.Add(content);
            panel.Controls.Add(headingRow);
            return panel;
        }
        private static NumericUpDown Number(decimal minimum, decimal maximum, decimal value, int places)
        {
            var number = new NumericUpDown();
            number.Minimum = minimum;
            number.Maximum = maximum;
            number.DecimalPlaces = places;
            number.Increment = places == 2 ? 0.01m : 0.1m;
            number.Value = value;
            number.Dock = DockStyle.Fill;
            number.TextAlign = HorizontalAlignment.Right;
            number.Margin = new Padding(4, 5, 0, 4);
            return number;
        }
        private static void ConfigureLabel(Label label, string text)
        {
            label.Text = text;
            label.Dock = DockStyle.Fill;
            label.TextAlign = ContentAlignment.MiddleLeft;
            label.AutoEllipsis = true;
        }
        private static Label Label(string text)
        {
            var label = new Label();
            ConfigureLabel(label, text);
            return label;
        }
        private void StyleButton(Button button)
        {
            button.FlatStyle = FlatStyle.Flat;
            button.FlatAppearance.BorderColor = Color.FromArgb(92, 96, 104);
            button.BackColor = Color.FromArgb(58, 62, 69);
            button.ForeColor = foreground;
        }
        private static void ConfigureColorButton(Button button)
        {
            button.Dock = DockStyle.Fill;
            button.FlatStyle = FlatStyle.Flat;
            button.Margin = new Padding(4, 4, 12, 4);
            button.FlatAppearance.BorderColor = Color.FromArgb(120, 124, 132);
        }
        private void PickColor(bool upper)
        {
            using (var dialog = new ColorDialog())
            {
                dialog.FullOpen = true;
                dialog.Color = upper ? top : bottom;
                if (dialog.ShowDialog(this) == DialogResult.OK)
                {
                    if (upper) top = dialog.Color; else bottom = dialog.Color;
                    Changed(this, EventArgs.Empty);
                }
            }
        }
        private static string Hex(Color color) { return String.Format("#{0:X2}{1:X2}{2:X2}", color.R, color.G, color.B); }
        private static void SetSwatch(Button button, Color color)
        {
            button.BackColor = color;
            button.ForeColor = color.GetBrightness() > 0.5f ? Color.Black : Color.White;
            button.Text = Hex(color);
        }
        private void Changed(object sender, EventArgs args)
        {
            if (!ready) return;
            RefreshOptions();
            if (lastReport.Length > 0) status.Text = "设置已改变，请重新写入；明细保留上次结果。";
        }
        private void RefreshOptions()
        {
            bool gradient = heightMode.Checked;
            bool fromTexture = textureMode.Checked;
            valueSettings.Visible = !fromTexture;
            textureSettings.Visible = fromTexture;
            gradientCard.Visible = !fromTexture;
            textureCard.Visible = fromTexture;
            origin.Enabled = gradient;
            start.Enabled = gradient && origin.SelectedIndex == 0;
            span.Enabled = gradient;
            clamp.Enabled = gradient;
            bool rgb = WriteR || WriteG || WriteB;
            lowColor.Enabled = rgb;
            highColor.Enabled = gradient && rgb;
            lowAlpha.Enabled = WriteA;
            highAlpha.Enabled = gradient && WriteA;
            lowTitle.Text = gradient ? "底部颜色" : "填充颜色";
            SetSwatch(lowColor, bottom);
            SetSwatch(highColor, top);
            preview.SetValues(bottom, top, (float)lowAlpha.Value, (float)highAlpha.Value, gradient, FromBottom,
                (double)start.Value, (double)span.Value, WriteA);
            UpdateBakeButton();
        }
        private void UpdateBakeButton()
        {
            bool any = WriteR || WriteG || WriteB || WriteA;
            bool missingTexture = textureMode.Checked && texture == null;
            bool singleModel = modelCount == 1 && otherCount == 0;
            bool scopeReady = !SelectedVerticesOnly || (singleModel && vertexContextValid && selectedVertexCount > 0);
            vertexReadout.Text = !SelectedVerticesOnly ? "可多选模型批量写入" : !singleModel ? "请单选一个模型" :
                !vertexContextValid ? vertexReason : "已选 " + selectedVertexCount + " / " + totalVertexCount + " 点";
            measurementTip.SetToolTip(vertexReadout, !SelectedVerticesOnly ? "写入所选模型的全部顶点。" :
                !singleModel ? "选中顶点模式需要单选一个几何模型。" : vertexContextValid ? "仅写入连接网格面的硬选择顶点；孤立点不计入可写数量。\n其他顶点颜色保持原值。" : vertexReason);
            bake.Enabled = !busy && modelCount > 0 && any && !missingTexture && scopeReady;
            bake.Text = !any ? "请至少勾选一个通道" : modelCount == 0 ? "请先选择模型" :
                SelectedVerticesOnly && !singleModel ? "请单选一个模型并选点" :
                SelectedVerticesOnly && !vertexContextValid ? "请进入可写入的顶点模式" :
                SelectedVerticesOnly && selectedVertexCount == 0 ? "请先选中要填充的顶点" :
                missingTexture ? "请先读取有效贴图" : SelectedVerticesOnly ? "写入 " + selectedVertexCount + " 个选中顶点" : "写入 " + modelCount + " 个整模型";
        }
        public void StartRefresh() { selectionTimer.Start(); }
        public void SetHeightMeasurement(string objectName, double height, double bottomZ, double topZ)
        {
            measuredHeight.Text = String.Format(CultureInfo.InvariantCulture, "{0:0.000} 米   ·   底部 {1:0.000} / 顶部 {2:0.000} 米", height, bottomZ, topZ);
            measurementTip.SetToolTip(measuredHeight, objectName + "\n" + measuredHeight.Text + "\n当前网格的世界 Z 高度；不改变映射高度。");
        }
        public void SetHeightUnavailable(string reason)
        {
            measuredHeight.Text = reason;
            measurementTip.SetToolTip(measuredHeight, reason);
        }
        public void SetRulerError(string reason)
        {
            heightRuler.Text = reason.Length == 0 ? "视口显示高度标尺" : "标尺异常（查看提示）";
            measurementTip.SetToolTip(heightRuler, reason);
        }
        public void SetMeasurementCost(int milliseconds)
        {
            // Avoid continuous heavy mesh evaluation on dense objects.
            selectionTimer.Interval = (int)Math.Max(500L, Math.Min(5000L, (long)milliseconds * 4));
        }
        public void SetSelection(int models, int other)
        {
            modelCount = models;
            otherCount = other;
            selection.Text = "已选模型 " + models + " 个" + (other > 0 ? " · 跳过其他对象 " + other + " 个" : "");
            UpdateBakeButton();
        }
        public void SetVertexSelection(int selected, int total, bool contextValid, string reason)
        {
            selectedVertexCount = selected;
            totalVertexCount = total;
            vertexContextValid = contextValid;
            vertexReason = reason;
            UpdateBakeButton();
        }
        public void SetBusy(bool value)
        {
            busy = value;
            options.Enabled = !value;
            viewport.Enabled = !value;
            heightRuler.Enabled = !value;
            details.Enabled = !value && lastReport.Length > 0;
            if (value) { selectionTimer.Stop(); status.Text = "正在写入并校验，请稍候……"; }
            else selectionTimer.Start();
            UpdateBakeButton();
        }
        public void SetResult(string summary, string report)
        {
            lastReport = report;
            status.Text = summary;
            details.Enabled = report.Length > 0;
        }
        private void ShowReport()
        {
            using (var form = new Form())
            using (var text = new TextBox())
            {
                form.Text = "VertexColorWriter · 处理明细";
                form.Font = bodyFont;
                form.Size = new Size(760, 500);
                form.StartPosition = FormStartPosition.CenterParent;
                text.Multiline = true;
                text.ReadOnly = true;
                text.ScrollBars = ScrollBars.Both;
                text.WordWrap = false;
                text.Dock = DockStyle.Fill;
                text.Text = lastReport.Replace("\r\n", "\n").Replace("\n", "\r\n");
                form.Controls.Add(text);
                form.ShowDialog(this);
            }
        }
        public bool IsGradient { get { return heightMode.Checked; } }
        public bool SelectedVerticesOnly { get { return writeScope.SelectedIndex == 1; } set { writeScope.SelectedIndex = value ? 1 : 0; } }
        public string VertexReadout { get { return vertexReadout.Text; } }
        public bool IsTexture { get { return textureMode.Checked; } }
        public TextureSource LoadedTexture { get { return texture; } }
        public int UVChannel { get { return (int)uvChannel.Value; } }
        public bool TextureIsColor { get { return texturePurpose.SelectedIndex == 0; } }
        public bool TextureBilinear { get { return textureFilter.SelectedIndex == 0; } }
        public bool TextureRepeat { get { return textureWrap.SelectedIndex == 1; } }
        public void SetTextureMode(int channel, bool color, bool bilinear, bool repeat)
        {
            textureMode.Checked = true;
            uvChannel.Value = channel;
            texturePurpose.SelectedIndex = color ? 0 : 1;
            textureFilter.SelectedIndex = bilinear ? 0 : 1;
            textureWrap.SelectedIndex = repeat ? 1 : 0;
            RefreshOptions();
        }
        public bool FromBottom { get { return origin.SelectedIndex == 1; } }
        public bool ClampRange { get { return clamp.Checked; } }
        public bool ShowColors { get { return viewport.Checked; } }
        public bool ShowHeightRuler { get { return heightRuler.Checked; } set { heightRuler.Checked = value; } }
        public bool IsBusy { get { return busy; } }
        public string HeightReadout { get { return measuredHeight.Text; } }
        public int RefreshInterval { get { return selectionTimer.Interval; } }
        public bool CanBake { get { return bake.Enabled; } }
        public bool HeightInputsEnabled { get { return span.Enabled; } }
        public bool StartInputEnabled { get { return start.Enabled; } }
        public bool WriteR { get { return channels[0] != null && channels[0].Checked; } }
        public bool WriteG { get { return channels[1] != null && channels[1].Checked; } }
        public bool WriteB { get { return channels[2] != null && channels[2].Checked; } }
        public bool WriteA { get { return channels[3] != null && channels[3].Checked; } }
        public double MappingHeight { get { return (double)span.Value; } }
        public double StartHeight { get { return (double)start.Value; } }
        public double LowR { get { return bottom.R / 255.0; } }
        public double LowG { get { return bottom.G / 255.0; } }
        public double LowB { get { return bottom.B / 255.0; } }
        public double LowA { get { return (double)lowAlpha.Value; } }
        public double HighR { get { return top.R / 255.0; } }
        public double HighG { get { return top.G / 255.0; } }
        public double HighB { get { return top.B / 255.0; } }
        public double HighA { get { return (double)highAlpha.Value; } }
        // Used by the UI smoke test and available to scripted callers.
        public void SetConfiguration(bool gradient, bool bottomOrigin, double height, double startAt, int mask, Color lower, Color upper, double alphaLow, double alphaHigh)
        {
            heightMode.Checked = gradient;
            solidMode.Checked = !gradient;
            origin.SelectedIndex = bottomOrigin ? 1 : 0;
            span.Value = (decimal)height;
            start.Value = (decimal)startAt;
            for (int i = 0; i < 4; i++) channels[i].Checked = (mask & (1 << i)) != 0;
            bottom = lower;
            top = upper;
            lowAlpha.Value = (decimal)alphaLow;
            highAlpha.Value = (decimal)alphaHigh;
            RefreshOptions();
        }
        protected override void Dispose(bool disposing)
        {
            if (disposing) { selectionTimer.Stop(); selectionTimer.Dispose(); measurementTip.Dispose(); texture = null; }
            base.Dispose(disposing);
            if (disposing)
            {
                if (loadedToolIcon != null) { loadedToolIcon.Dispose(); loadedToolIcon = null; }
                foreach (Image icon in ownedIcons) icon.Dispose();
                ownedIcons.Clear();
                headingFont.Dispose(); bodyFont.Dispose();
            }
        }
    }

    // Small UI glyphs are drawn from geometry so edges stay clear at button sizes.
    // The entry/write icon is the accompanying generated artwork, loaded separately.
    internal static class PanelGlyphs
    {
        public static Bitmap Create(string name, int size)
        {
            var bitmap = new Bitmap(size, size);
            using (var g = Graphics.FromImage(bitmap))
            using (var green = new SolidBrush(Color.FromArgb(118, 183, 71)))
            using (var white = new SolidBrush(Color.FromArgb(236, 240, 244)))
            using (var line = new Pen(Color.FromArgb(236, 240, 244), 2.1f))
            using (var accent = new Pen(Color.FromArgb(118, 183, 71), 2.5f))
            {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.ScaleTransform(size / 24f, size / 24f);
                line.StartCap = line.EndCap = LineCap.Round;
                accent.StartCap = accent.EndCap = LineCap.Round;
                if (name == "height" || name == "ruler")
                {
                    g.DrawLine(accent, 6, 4, 6, 20);
                    g.DrawLines(accent, new PointF[] { new PointF(3,7),new PointF(6,4),new PointF(9,7) });
                    g.DrawLines(accent, new PointF[] { new PointF(3,17),new PointF(6,20),new PointF(9,17) });
                    if (name == "height")
                    {
                        g.FillRectangle(white, 13, 4, 8, 5);
                        g.FillRectangle(green, 13, 10, 8, 5);
                        g.DrawRectangle(line, 14, 17, 6, 3);
                    }
                    else
                    {
                        g.DrawLine(line, 15, 3, 15, 21);
                        for (int y=4; y<=20; y+=4) g.DrawLine(line, 15, y, y%8==4 ? 21 : 19, y);
                    }
                }
                else if (name == "channels")
                {
                    Color[] colors = { Color.FromArgb(237,71,71), Color.FromArgb(118,183,71), Color.FromArgb(69,143,236), Color.WhiteSmoke };
                    for (int i=0; i<4; i++) using (var fill = new SolidBrush(colors[i]))
                        g.FillEllipse(fill, 3+(i%2)*11, 3+(i/2)*11, 8, 8);
                }
                else if (name == "color")
                {
                    using (var drop = new GraphicsPath())
                    {
                        drop.AddBezier(12,2,10,6,4,11,4,15);
                        drop.AddBezier(4,15,4,25,20,25,20,15);
                        drop.AddBezier(20,15,20,11,14,6,12,2);
                        g.FillPath(green,drop);
                    }
                    g.DrawArc(line, 7,12,9,7,80,90);
                }
                else if (name == "texture")
                {
                    g.DrawRectangle(line, 3,4,18,16);
                    g.FillEllipse(green, 6,7,4,4);
                    g.FillPolygon(green, new Point[] { new Point(5,18),new Point(11,12),new Point(14,15),new Point(17,11),new Point(20,18) });
                }
                else if (name == "folder")
                {
                    g.FillPolygon(green, new Point[] {new Point(2,6),new Point(9,6),new Point(11,9),new Point(21,9),new Point(20,20),new Point(3,20)});
                    g.DrawLine(line, 4,11,19,11);
                    g.DrawLine(line, 15,14,15,18); g.DrawLine(line, 13,16,17,16);
                }
                else if (name == "reload")
                {
                    g.DrawArc(accent,4,4,16,16,45,285);
                    g.FillPolygon(white, new Point[] { new Point(16,4),new Point(22,4),new Point(22,10) });
                }
                else if (name == "details")
                {
                    for (int y=6; y<=18; y+=6) { g.FillEllipse(green,3,y-2,4,4); g.DrawLine(line,10,y,21,y); }
                }
                else // mesh + pen, used if the external tool artwork is missing
                {
                    g.DrawPolygon(line,new Point[] {new Point(10,3),new Point(20,11),new Point(11,21),new Point(2,12)});
                    g.FillEllipse(green,7,0,6,6); g.FillEllipse(green,0,9,6,6);
                    g.DrawLine(accent,11,18,21,8);
                }
            }
            return bitmap;
        }
    }

    internal sealed class TexturePreview : Control
    {
        private Bitmap image;
        public TexturePreview() { DoubleBuffered = true; ResizeRedraw = true; }
        public void SetImage(Bitmap value)
        {
            if (image != null) image.Dispose();
            image = value;
            Invalidate();
        }
        protected override void OnPaint(PaintEventArgs args)
        {
            base.OnPaint(args);
            var g = args.Graphics;
            var area = new Rectangle(4, 12, Math.Max(1, Width - 8), Math.Max(1, Height - 116));
            using (var dark = new SolidBrush(Color.FromArgb(75, 79, 85)))
            using (var light = new SolidBrush(Color.FromArgb(125, 131, 140)))
            using (var text = new SolidBrush(ForeColor))
            {
                for (int y = area.Top; y < area.Bottom; y += 16)
                    for (int x = area.Left; x < area.Right; x += 16)
                        g.FillRectangle(((x - area.Left) / 16 + (y - area.Top) / 16) % 2 == 0 ? dark : light,
                            x, y, Math.Min(16, area.Right - x), Math.Min(16, area.Bottom - y));
                if (image != null)
                {
                    double scale = Math.Min((double)area.Width / image.Width, (double)area.Height / image.Height);
                    int w = Math.Max(1, (int)(image.Width * scale)), h = Math.Max(1, (int)(image.Height * scale));
                    g.DrawImage(image, area.X + (area.Width - w) / 2, area.Y + (area.Height - h) / 2, w, h);
                }
                else g.DrawString("选择贴图后显示原图", Font, text, area.X + 8, area.Y + 20);
                g.DrawString("原图预览 · 棋盘格表示透明\n写入效果取决于 UV 和顶点密度\n未勾选的通道保留", Font, text,
                    new RectangleF(4, Height - 94, Width - 8, 94));
            }
        }
        protected override void Dispose(bool disposing)
        { if (disposing) SetImage(null); base.Dispose(disposing); }
    }

    internal sealed class GradientPreview : Control
    {
        private Color lower = Color.Black, upper = Color.White;
        private bool gradient = true, relative, showAlpha;
        private double origin, span = 1;
        public GradientPreview() { DoubleBuffered = true; ResizeRedraw = true; }
        public void SetValues(Color low, Color high, float lowA, float highA, bool useGradient, bool fromBottom, double start, double height, bool alphaEnabled)
        {
            lower = Color.FromArgb((int)(255 * (alphaEnabled ? lowA : 1)), low);
            upper = Color.FromArgb((int)(255 * (alphaEnabled ? highA : 1)), high);
            gradient = useGradient; relative = fromBottom; origin = fromBottom ? 0 : start; span = height;
            showAlpha = alphaEnabled;
            Invalidate();
        }
        private string HeightText(double height)
        {
            return (relative ? "离底 " : "") + height.ToString("0.###", CultureInfo.InvariantCulture) + " 米";
        }
        protected override void OnPaint(PaintEventArgs args)
        {
            base.OnPaint(args);
            var g = args.Graphics;
            int line = Font.Height + 5;
            int left = 12, barTop = line + 8, barBottom = Math.Max(barTop + 40, Height - line * 3);
            int barWidth = Math.Max(42, Math.Min(78, Width / 3));
            var rect = new Rectangle(left, barTop, barWidth, barBottom - barTop);
            using (var text = new SolidBrush(ForeColor))
            using (var muted = new SolidBrush(Color.FromArgb(181, 186, 196)))
            using (var border = new Pen(Color.FromArgb(110, 116, 126)))
            using (var dark = new SolidBrush(Color.FromArgb(90, 94, 100)))
            using (var light = new SolidBrush(Color.FromArgb(154, 158, 166)))
            {
                g.DrawString(gradient ? "高处 ↑" : "固定填充", Font, text, 8, 0);
                for (int y = rect.Top; y < rect.Bottom; y += 10)
                    for (int x = rect.Left; x < rect.Right; x += 10)
                        g.FillRectangle(((x - rect.Left) / 10 + (y - rect.Top) / 10) % 2 == 0 ? dark : light,
                            x, y, Math.Min(10, rect.Right - x), Math.Min(10, rect.Bottom - y));
                using (var fill = new LinearGradientBrush(rect, gradient ? upper : lower, lower, LinearGradientMode.Vertical)) g.FillRectangle(fill, rect);
                g.DrawRectangle(border, rect);
                int textX = rect.Right + 18;
                int middle = (rect.Top + rect.Bottom) / 2;
                if (gradient)
                {
                    g.DrawLine(border, rect.Right, rect.Top, rect.Right + 10, rect.Top);
                    g.DrawLine(border, rect.Right, middle, rect.Right + 10, middle);
                    g.DrawLine(border, rect.Right, rect.Bottom, rect.Right + 10, rect.Bottom);
                    g.DrawString(HeightText(origin + span) + "\n顶部颜色", Font, text, textX, rect.Top);
                    g.DrawString(HeightText(origin + span / 2) + "\n过渡中点", Font, text, textX, middle - line);
                    g.DrawString(HeightText(origin) + "\n底部颜色", Font, text, textX, rect.Bottom - line * 2);
                }
                else g.DrawString("所有高度\n使用同一颜色", Font, text, textX, middle - line);
                g.DrawString(showAlpha ? "棋盘格表示 Alpha" : "预览所设 RGB 颜色", Font, muted, 8, Height - line * 2);
                g.DrawString("未选通道保留，结果可能不同", Font, muted, 8, Height - line);
            }
        }
    }
}
