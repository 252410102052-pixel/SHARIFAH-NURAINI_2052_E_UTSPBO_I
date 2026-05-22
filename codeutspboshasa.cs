using System;
using System.Collections.Generic;

namespace OOPPark
{
  
    abstract class TiketWisata
    {
        private string namaPengunjung;
        private string idTiket;
        private string wahanaUtama;

        public string NamaPengunjung
        {
            get { return namaPengunjung; }
            set { namaPengunjung = value; }
        }

        public string IdTiket
        {
            get { return idTiket; }
            set { idTiket = value; }
        }

        public string WahanaUtama
        {
            get { return wahanaUtama; }
            set { wahanaUtama = value; }
        }

        protected List<RiwayatKunjungan> riwayat = new List<RiwayatKunjungan>();

        public TiketWisata(string nama, string id, string wahana)
        {
            NamaPengunjung = nama;
            IdTiket = id;
            WahanaUtama = wahana;
        }


        public void tampilInfo()
        {
            Console.WriteLine($"Pengunjung: {NamaPengunjung} | Tiket: {IdTiket} | Wahana: {WahanaUtama}");
        }

        public abstract int hitungTotalTiket(int jumlahTiket);

        public void tambahKunjungan(RiwayatKunjungan data)
        {
            riwayat.Add(data);
        }

        public void cetakRiwayat()
        {
            int no = 1;
            foreach (var item in riwayat)
            {
                Console.WriteLine($"{no}. {item.JenisTiket} | {item.JumlahTiket} tiket | {item.TanggalKunjungan}");
                no++;
            }
        }
    }

    class TiketWeekday : TiketWisata
    {
        public int hargaMasuk;

        public TiketWeekday(string nama, string id, string wahana, int harga)
            : base(nama, id, wahana)
        {
            hargaMasuk = harga;
        }

        public override int hitungTotalTiket(int jumlahTiket)
        {
            return jumlahTiket * hargaMasuk;
        }
    }

    class TiketWeekend : TiketWisata
    {
        public int hargaMasuk;
        public int biayaTerusanWahana;

        public TiketWeekend(string nama, string id, string wahana,
            int harga, int biayaTerusan)
            : base(nama, id, wahana)
        {
            hargaMasuk = harga;
            biayaTerusanWahana = biayaTerusan;
        }

        public override int hitungTotalTiket(int jumlahTiket)
        {
            return (jumlahTiket * hargaMasuk) + biayaTerusanWahana;
        }
    }

    class RiwayatKunjungan
    {
        public string JenisTiket { get; set; }
        public int JumlahTiket { get; set; }
        public string TanggalKunjungan { get; set; }

        public RiwayatKunjungan(string jenis, int jumlah, string tanggal)
        {
            JenisTiket = jenis;
            JumlahTiket = jumlah;
            TanggalKunjungan = tanggal;
        }
    }
    class Program
    {
        static void Main(string[] args)
        {
            TiketWeekend data = new TiketWeekend(
                "Feri",
                "TW001",
                "Roller Coaster",
                50000,
                25000
            );

            data.tampilInfo();

            int total = data.hitungTotalTiket(4);

            Console.WriteLine($"Total Tiket: Rp {total}");
            data.tambahKunjungan(
                new RiwayatKunjungan(
                    "Weekend",
                    4,
                    "18-10-2025"
                )
            );

            data.cetakRiwayat();
        }
    }
}