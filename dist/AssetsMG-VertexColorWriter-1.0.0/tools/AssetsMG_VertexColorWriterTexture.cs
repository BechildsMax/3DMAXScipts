// VertexColorWriter texture reader v1.2.0. Concatenated with the UI source by MAXScript.
namespace AssetsMG.Tools.VertexColorWriter
{
    using System;
    using System.Drawing;
    using System.Drawing.Imaging;
    using System.IO;
    using System.Runtime.InteropServices;

    public sealed class TextureSample
    {
        public double R { get; private set; }
        public double G { get; private set; }
        public double B { get; private set; }
        public double A { get; private set; }
        internal TextureSample(double r, double g, double b, double a) { R = r; G = g; B = b; A = a; }
    }

    // Immutable, straight-alpha BGRA bytes, top-left origin. Loading releases the file immediately.
    public sealed class TextureSource
    {
        private readonly byte[] pixels;
        private static readonly double[] linear = BuildLinearTable();
        public int Width { get; private set; }
        public int Height { get; private set; }
        public string FilePath { get; private set; }
        private TextureSource(string path, int width, int height, byte[] data)
        { FilePath = path; Width = width; Height = height; pixels = data; }

        private static double[] BuildLinearTable()
        {
            var values = new double[256];
            for (int i = 0; i < 256; i++)
            {
                double c = i / 255.0;
                values[i] = c <= 0.04045 ? c / 12.92 : Math.Pow((c + 0.055) / 1.055, 2.4);
            }
            return values;
        }
        private static void CheckSize(int width, int height)
        {
            if (width < 1 || height < 1 || width > 8192 || height > 8192 || (long)width * height > 16777216L)
                throw new InvalidDataException("图片尺寸需为 1–8192 像素，总像素不超过 1677 万（如 4096 × 4096）。");
        }
        public static TextureSource Load(string path)
        {
            path = Path.GetFullPath(path);
            string extension = Path.GetExtension(path).ToLowerInvariant();
            if (extension == ".tga") return LoadTga(path);
            if (extension != ".png" && extension != ".jpg" && extension != ".jpeg" && extension != ".bmp")
                throw new InvalidDataException("请选择 PNG、JPG、BMP 或 TGA 图片；暂不支持 HDR、EXR、UDIM。");
            if (extension == ".png")
            {
                // GDI+ silently reduces 16-bit PNGs: reject instead of implying lossless numeric input.
                using (var stream = File.OpenRead(path))
                {
                    var header = new byte[25];
                    if (stream.Read(header, 0, header.Length) != header.Length || header[0] != 137 || header[1] != 80 || header[2] != 78 || header[3] != 71)
                        throw new InvalidDataException("PNG 文件头无效。");
                    if (header[24] > 8) throw new InvalidDataException("请先将 PNG 转为每通道 8 位；不自动降位深。");
                }
            }
            using (var bitmap = (Bitmap)Image.FromFile(path, false))
            {
                CheckSize(bitmap.Width, bitmap.Height);
                if (Image.GetPixelFormatSize(bitmap.PixelFormat) > 32)
                    throw new InvalidDataException("仅支持每通道 8 位图片。");
                var bytes = new byte[checked(bitmap.Width * bitmap.Height * 4)];
                var data = bitmap.LockBits(new Rectangle(0, 0, bitmap.Width, bitmap.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
                try
                {
                    for (int y = 0; y < bitmap.Height; y++)
                        Marshal.Copy(IntPtr.Add(data.Scan0, y * data.Stride), bytes, y * bitmap.Width * 4, bitmap.Width * 4);
                }
                finally { bitmap.UnlockBits(data); }
                return new TextureSource(path, bitmap.Width, bitmap.Height, bytes);
            }
        }
        private static TextureSource LoadTga(string path)
        {
            using (var reader = new BinaryReader(File.OpenRead(path)))
            {
                byte[] header = reader.ReadBytes(18);
                if (header.Length != 18) throw new InvalidDataException("TGA 文件头不完整。");
                int width = header[12] | (header[13] << 8), height = header[14] | (header[15] << 8);
                CheckSize(width, height);
                int kind = header[2], depth = header[16], descriptor = header[17];
                bool gray = kind == 3 || kind == 11, rle = kind == 10 || kind == 11;
                int alphaBits = descriptor & 15;
                if (header[1] != 0 || (kind != 2 && kind != 10 && !gray) || (descriptor & 192) != 0 ||
                    (gray ? depth != 8 : depth != 24 && depth != 32) ||
                    (depth == 32 ? alphaBits != 0 && alphaBits != 8 : alphaBits != 0))
                    throw new InvalidDataException("TGA 仅支持无调色板的 24/32 位真彩色或 8 位灰度（含 RLE）。");
                bool useAlpha = depth == 32 && alphaBits == 8;
                // TGA 2.0 attributes: ignore undefined alpha, reject premultiplied alpha.
                if (reader.BaseStream.Length >= 26)
                {
                    reader.BaseStream.Position = reader.BaseStream.Length - 26;
                    uint extensionOffset = reader.ReadUInt32();
                    reader.ReadUInt32();
                    string signature = System.Text.Encoding.ASCII.GetString(reader.ReadBytes(18));
                    if (signature == "TRUEVISION-XFILE.\0" && extensionOffset != 0)
                    {
                        if ((long)extensionOffset + 495 > reader.BaseStream.Length - 26)
                            throw new InvalidDataException("TGA 扩展区无效。");
                        reader.BaseStream.Position = extensionOffset + 494L;
                        byte attributes = reader.ReadByte();
                        if (attributes == 4) throw new InvalidDataException("不支持预乘 Alpha 的 TGA，请导出直通 Alpha 图片。");
                        if (attributes > 4) throw new InvalidDataException("不支持此 TGA Alpha 类型。");
                        if (attributes <= 1) useAlpha = false;
                    }
                }
                reader.BaseStream.Position = 18 + header[0];
                int count = checked(width * height), written = 0, bytesPerPixel = depth / 8;
                var bytes = new byte[count * 4];
                while (written < count)
                {
                    int packet = rle ? reader.ReadByte() : 0;
                    int length = rle ? (packet & 127) + 1 : 1;
                    bool repeated = rle && (packet & 128) != 0;
                    if (length > count - written) throw new InvalidDataException("TGA RLE 数据超出图片范围。");
                    byte[] pixel = null;
                    for (int i = 0; i < length; i++)
                    {
                        if (!repeated || i == 0) pixel = reader.ReadBytes(bytesPerPixel);
                        if (pixel.Length != bytesPerPixel) throw new InvalidDataException("TGA 像素数据不完整。");
                        int x = written % width, y = written / width;
                        if ((descriptor & 16) != 0) x = width - 1 - x;
                        if ((descriptor & 32) == 0) y = height - 1 - y;
                        int offset = (y * width + x) * 4;
                        bytes[offset] = pixel[0];
                        bytes[offset + 1] = gray ? pixel[0] : pixel[1];
                        bytes[offset + 2] = gray ? pixel[0] : pixel[2];
                        bytes[offset + 3] = useAlpha ? pixel[3] : (byte)255;
                        written++;
                    }
                }
                return new TextureSource(path, width, height, bytes);
            }
        }
        private static int Address(int coordinate, int size, bool repeat)
        {
            if (repeat) return ((coordinate % size) + size) % size;
            return Math.Max(0, Math.Min(size - 1, coordinate));
        }
        private double Component(int x, int y, int component, bool srgb, bool repeat)
        {
            byte value = pixels[(Address(y, Height, repeat) * Width + Address(x, Width, repeat)) * 4 + component];
            return srgb && component != 3 ? linear[value] : value / 255.0;
        }
        public TextureSample Sample(double u, double v, bool srgb, bool bilinear, bool repeat)
        {
            if (Double.IsNaN(u) || Double.IsInfinity(u) || Double.IsNaN(v) || Double.IsInfinity(v))
                throw new ArgumentException("UV 包含无效数值。");
            u = repeat ? u - Math.Floor(u) : Math.Max(0, Math.Min(1, u));
            v = repeat ? v - Math.Floor(v) : Math.Max(0, Math.Min(1, v));
            double x = u * Width - (bilinear ? 0.5 : 0), y = (1 - v) * Height - (bilinear ? 0.5 : 0);
            int x0 = (int)Math.Floor(x), y0 = (int)Math.Floor(y);
            double tx = x - x0, ty = y - y0;
            var result = new double[4];
            for (int c = 0; c < 4; c++)
            {
                double value = Component(x0, y0, c, srgb, repeat);
                if (bilinear)
                {
                    double a = value * (1 - tx) + Component(x0 + 1, y0, c, srgb, repeat) * tx;
                    double b = Component(x0, y0 + 1, c, srgb, repeat) * (1 - tx) + Component(x0 + 1, y0 + 1, c, srgb, repeat) * tx;
                    value = a * (1 - ty) + b * ty;
                }
                result[c] = value;
            }
            return new TextureSample(result[2], result[1], result[0], result[3]);
        }
        public Bitmap CreateThumbnail()
        {
            double scale = Math.Min(1.0, 512.0 / Math.Max(Width, Height));
            int width = Math.Max(1, (int)(Width * scale)), height = Math.Max(1, (int)(Height * scale));
            var thumbnail = new Bitmap(width, height, PixelFormat.Format32bppArgb);
            var data = thumbnail.LockBits(new Rectangle(0, 0, width, height), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            try
            {
                var row = new byte[width * 4];
                for (int y = 0; y < height; y++)
                {
                    for (int x = 0; x < width; x++)
                        Buffer.BlockCopy(pixels, (((y * Height / height) * Width) + x * Width / width) * 4, row, x * 4, 4);
                    Marshal.Copy(row, 0, IntPtr.Add(data.Scan0, y * data.Stride), row.Length);
                }
            }
            finally { thumbnail.UnlockBits(data); }
            return thumbnail;
        }
    }
}
