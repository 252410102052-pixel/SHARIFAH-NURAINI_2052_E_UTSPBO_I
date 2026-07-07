-- =========================================================================
-- 1. DROP OBJECTS JIKA SUDAH ADA (Agar script bisa di-run berulang kali/Idempotent)
-- =========================================================================
DROP TRIGGER IF EXISTS trg_log_operasional_distribusi ON distribusi;
DROP TRIGGER IF EXISTS trg_log_operasional_qc ON kontrol_kualitas;
DROP TRIGGER IF EXISTS trg_log_operasional_produksi ON produksi;
DROP TRIGGER IF EXISTS trg_log_operasional_batch ON batch_limbah;
DROP TRIGGER IF EXISTS trg_log_operasional_jadwal ON jadwal_pengangkutan;
DROP TRIGGER IF EXISTS trg_log_operasional_kendaraan ON kendaraan;
DROP TRIGGER IF EXISTS trg_log_operasional_petugas ON petugas;

DROP VIEW IF EXISTS v_grid_kontrol_kualitas;
DROP VIEW IF EXISTS v_grid_produksi;
DROP VIEW IF EXISTS v_grid_distribusi;
DROP VIEW IF EXISTS v_grid_jadwal_pengangkutan;
DROP VIEW IF EXISTS v_grid_batch_limbah;

DROP TABLE IF EXISTS riwayat_perubahan;
DROP TABLE IF EXISTS distribusi;
DROP TABLE IF EXISTS kontrol_kualitas;
DROP TABLE IF EXISTS produksi;
DROP TABLE IF EXISTS batch_limbah;
DROP TABLE IF EXISTS jadwal_pengangkutan;
DROP TABLE IF EXISTS produk;
DROP TABLE IF EXISTS petugas;
DROP TABLE IF EXISTS penerima;
DROP TABLE IF EXISTS pabrik;
DROP TABLE IF EXISTS pengguna;

DROP TYPE IF EXISTS enum_aksi_log;
DROP TYPE IF EXISTS enum_status_distribusi;
DROP TYPE IF EXISTS enum_status_produksi;
DROP TYPE IF EXISTS enum_status_jadwal;
DROP TYPE IF EXISTS enum_status_batch;
DROP TYPE IF EXISTS enum_role;

-- =========================================================================
-- 2. ENUM TYPES CREATION
-- =========================================================================
CREATE TYPE enum_role AS ENUM ('Operator', 'Quality Control', 'Admin');
CREATE TYPE enum_status_batch AS ENUM ('Siap Pakai', 'Diproses', 'Selesai');
CREATE TYPE enum_status_jadwal AS ENUM ('Diproses', 'Selesai');
CREATE TYPE enum_status_produksi AS ENUM ('Diproses', 'Selesai');
CREATE TYPE enum_status_distribusi AS ENUM ('Diproses', 'Dikirim', 'Selesai');
CREATE TYPE enum_aksi_log AS ENUM ('INSERT', 'UPDATE', 'DELETE');

-- =========================================================================
-- 3. TABLES CREATION (Urutan disesuaikan berdasarkan Foreign Key)
-- =========================================================================
CREATE TABLE pengguna (
    id_pengguna SERIAL PRIMARY KEY,
    username VARCHAR(32) NOT NULL,
    password VARCHAR(50) NOT NULL,
    role enum_role NOT NULL
);

CREATE TABLE pabrik (
    id_pabrik SERIAL PRIMARY KEY,
    nama_pabrik VARCHAR(50) NOT NULL,
    alamat TEXT NOT NULL,
    no_telepon VARCHAR(20) NOT NULL
);

CREATE TABLE penerima (
    id_penerima SERIAL PRIMARY KEY,
    nama_penerima VARCHAR(100) NOT NULL,
    alamat VARCHAR(200) NOT NULL,
    no_telepon VARCHAR(20) NOT NULL
);

CREATE TABLE petugas (
    id_petugas SERIAL PRIMARY KEY,
    nama_petugas VARCHAR(50) NOT NULL,
    no_telepon VARCHAR(20) NOT NULL
);

CREATE TABLE kendaraan (
    id_kendaraan SERIAL PRIMARY KEY,
    nama_kendaraan VARCHAR(32) NOT NULL,
    kapasitas DECIMAL(10, 2) NOT NULL
);

CREATE TABLE produk (
    id_produk SERIAL PRIMARY KEY,
    nama_produk VARCHAR(64) NOT NULL,
    stok DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    gambar_produk TEXT NOT NULL,
    satuan VARCHAR(10) NOT NULL
);

CREATE TABLE jadwal_pengangkutan (
    id_jadwal SERIAL PRIMARY KEY,
    tanggal_pengangkutan DATE NOT NULL,
    status enum_status_jadwal NOT NULL,
    catatan TEXT,
    petugas_id_petugas INT NOT NULL REFERENCES petugas(id_petugas),
    kendaraan_id_kendaraan INT NOT NULL REFERENCES kendaraan(id_kendaraan)
);

CREATE TABLE batch_limbah (
    id_batch SERIAL PRIMARY KEY,
    jumlah DECIMAL(10, 2) NOT NULL,
    tanggal_masuk DATE NOT NULL,
    status enum_status_batch NOT NULL,
    gambar_barang TEXT,
    keterangan TEXT,
    pabrik_id_pabrik INT NOT NULL REFERENCES pabrik(id_pabrik),
    jadwal_pengangkutan_id_jadwal INT REFERENCES jadwal_pengangkutan(id_jadwal) UNIQUE
);

CREATE TABLE produksi (
    id_produksi SERIAL PRIMARY KEY,
    jumlah_bahan DECIMAL(10, 2) NOT NULL,
    jumlah_hasil DECIMAL(10, 2) NOT NULL,
    biaya_produksi DECIMAL(12, 2) NOT NULL,
    tanggal_produksi DATE NOT NULL,
    status enum_status_produksi NOT NULL,
    batch_limbah_id_batch INT NOT NULL REFERENCES batch_limbah(id_batch),
    pengguna_id_pengguna INT NOT NULL REFERENCES pengguna(id_pengguna),
    produk_id_produk INT NOT NULL REFERENCES produk(id_produk)
);

CREATE TABLE kontrol_kualitas (
    id_kontrol SERIAL PRIMARY KEY,
    jumlah_lolos DECIMAL(10,2) NOT NULL,
    jumlah_gagal DECIMAL(10,2) NOT NULL,
    nilai_kualitas INT NOT NULL,
    catatan TEXT,
    tanggal_pemeriksaan DATE NOT NULL,
    pengguna_id_pengguna INT NOT NULL REFERENCES pengguna(id_pengguna),
    produksi_id_produksi INT NOT NULL REFERENCES produksi(id_produksi) UNIQUE,
    CONSTRAINT chk_nilai_kualitas CHECK (nilai_kualitas >= 0 AND nilai_kualitas <= 100)
);

CREATE TABLE distribusi (
    id_distribusi SERIAL PRIMARY KEY,
    jumlah_produk DECIMAL(10, 2) NOT NULL,
    tanggal_distribusi DATE NOT NULL,
    status enum_status_distribusi NOT NULL,
    produk_id_produk INT NOT NULL REFERENCES produk(id_produk),
    penerima_id_penerima INT NOT NULL REFERENCES penerima(id_penerima)
);

CREATE TABLE riwayat_perubahan (
    id_riwayat SERIAL PRIMARY KEY,
    nama_tabel VARCHAR(32) NOT NULL,
    aksi enum_aksi_log NOT NULL,
    data_lama TEXT, -- Diubah jadi nullable karena INSERT tidak punya data lama
    data_baru TEXT, -- Diubah jadi nullable karena DELETE tidak punya data baru
    tanggal_perubahan TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    pengguna_id_pengguna INT NOT NULL REFERENCES pengguna(id_pengguna)
);

-- =========================================================================
-- 4. FUNCTIONS & TRIGGERS LOG AUDIT CREATION
-- =========================================================================
CREATE OR REPLACE FUNCTION fungsi_trg_log_perubahan()
RETURNS TRIGGER AS $$
DECLARE
    v_id_pengguna INT;
BEGIN
    IF TG_TABLE_NAME IN ('produksi', 'kontrol_kualitas') THEN
        IF TG_OP = 'DELETE' THEN
            v_id_pengguna := OLD.pengguna_id_pengguna;
        ELSE
            v_id_pengguna := NEW.pengguna_id_pengguna;
        END IF;
    ELSE
        v_id_pengguna := 1; 
    END IF;

    IF (TG_OP = 'INSERT') THEN
        INSERT INTO riwayat_perubahan (nama_tabel, aksi, data_lama, data_baru, pengguna_id_pengguna)
        VALUES (TG_TABLE_NAME, 'INSERT'::enum_aksi_log, NULL, NEW::TEXT, v_id_pengguna);
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO riwayat_perubahan (nama_tabel, aksi, data_lama, data_baru, pengguna_id_pengguna)
        VALUES (TG_TABLE_NAME, 'UPDATE'::enum_aksi_log, OLD::TEXT, NEW::TEXT, v_id_pengguna);
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO riwayat_perubahan (nama_tabel, aksi, data_lama, data_baru, pengguna_id_pengguna)
        VALUES (TG_TABLE_NAME, 'DELETE'::enum_aksi_log, OLD::TEXT, NULL, v_id_pengguna);
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_operasional_petugas AFTER INSERT OR UPDATE OR DELETE ON petugas FOR EACH ROW EXECUTE FUNCTION fungsi_trg_log_perubahan();
CREATE TRIGGER trg_log_operasional_kendaraan AFTER INSERT OR UPDATE OR DELETE ON kendaraan FOR EACH ROW EXECUTE FUNCTION fungsi_trg_log_perubahan();
CREATE TRIGGER trg_log_operasional_jadwal AFTER INSERT OR UPDATE OR DELETE ON jadwal_pengangkutan FOR EACH ROW EXECUTE FUNCTION fungsi_trg_log_perubahan();
CREATE TRIGGER trg_log_operasional_batch AFTER INSERT OR UPDATE OR DELETE ON batch_limbah FOR EACH ROW EXECUTE FUNCTION fungsi_trg_log_perubahan();
CREATE TRIGGER trg_log_operasional_produksi AFTER INSERT OR UPDATE OR DELETE ON produksi FOR EACH ROW EXECUTE FUNCTION fungsi_trg_log_perubahan();
CREATE TRIGGER trg_log_operasional_qc AFTER INSERT OR UPDATE OR DELETE ON kontrol_kualitas FOR EACH ROW EXECUTE FUNCTION fungsi_trg_log_perubahan();
CREATE TRIGGER trg_log_operasional_distribusi AFTER INSERT OR UPDATE OR DELETE ON distribusi FOR EACH ROW EXECUTE FUNCTION fungsi_trg_log_perubahan();

-- =========================================================================
-- 5. DATA INSERTS (DML)
-- =========================================================================
INSERT INTO pengguna (username, password, role) VALUES  
('superadmin', 'admin123', 'Admin'),      
('operator1', 'op123', 'Operator'),       
('qc1', 'qc123', 'Quality Control');      

INSERT INTO pabrik (nama_pabrik, alamat, no_telepon) VALUES 
('Internal Pabrik (Reject QC)', 'Area Produksi Utama', '-'), 
('PG Semboro', 'Kec. Tanggul, Jember', '0331-8419'),
('PG Jatiroto', 'Kecamatan Jatiroto, Lumajang', '0334-8822');

INSERT INTO produk (nama_produk, gambar_produk, satuan) VALUES  
('Arang Briket', 'arang_briket.png', 'Kg'),
('Pupuk Kompos', 'pupuk_kompos.png', 'Kg'),
('Pakan Ternak', 'pakan_ternak.png', 'Kg');

INSERT INTO penerima (nama_penerima, alamat, no_telepon) VALUES
('PT. Arang Hitam Nusantara', 'Kawasan Industri Gresik', '0812-1111'),
('Koperasi Tani Makmur Sejahtera', 'Jl. Raya Sukodono, Lumajang', '0813-2222'),
('CV. Ternak Gemuk Lestari', 'Jl. Kenanga No. 5, Probolinggo', '0811-3333'),
('PT. Hitam Legam Jaya', 'Jl. Purbasari No. 99, Karanganyar', '0816-7653'),
('Ternak Hewan Sehat', 'Jl. Jawa No. 32, Karangbayat', '0822-9988'),
('PT. Gudang Subur', 'Jl. Pandanwangi No. 317, Bali', '0899-1111'); 

INSERT INTO petugas (nama_petugas, no_telepon) VALUES
('Budi Santoso', '0852-1234'),
('Siti Aminah', '0852-5678');

INSERT INTO kendaraan (nama_kendaraan, kapasitas) VALUES
('Truk PickUp L300 (P 1234 UG)', 500.00),
('Truk Isuzu Traga (L 5678 AA)', 500.00);

-- --- SIKLUS I ---
INSERT INTO jadwal_pengangkutan (id_jadwal, tanggal_pengangkutan, status, catatan, petugas_id_petugas, kendaraan_id_kendaraan) VALUES
(1, '2026-03-01', 'Selesai', 'Ambil ampas tebu 3 kwintal di PG Semboro', 1, 1);

INSERT INTO batch_limbah (id_batch, jumlah, tanggal_masuk, status, gambar_barang, keterangan, pabrik_id_pabrik, jadwal_pengangkutan_id_jadwal) VALUES
(1, 300.00, '2026-03-01', 'Selesai', 'ampas1.png', 'Ampas Tebu Utama Maret', 2, 1);

INSERT INTO produksi (id_produksi, jumlah_bahan, jumlah_hasil, biaya_produksi, tanggal_produksi, status, batch_limbah_id_batch, pengguna_id_pengguna, produk_id_produk) VALUES
(1, 100.00, 85.00, 400000.00, '2026-03-02', 'Selesai', 1, 2, 1), 
(2, 100.00, 90.00, 300000.00, '2026-03-02', 'Selesai', 1, 2, 2), 
(3, 100.00, 85.00, 500000.00, '2026-03-02', 'Selesai', 1, 2, 3); 

INSERT INTO kontrol_kualitas (id_kontrol, jumlah_lolos, jumlah_gagal, nilai_kualitas, catatan, tanggal_pemeriksaan, pengguna_id_pengguna, produksi_id_produksi) VALUES 
(1, 70.00, 15.00, 85, '15kg pecah, oper ke batch internal untuk juni', '2026-03-03', 3, 1), 
(2, 90.00, 0.00, 100, 'Kompos matang sempurna', '2026-03-03', 3, 2),                                          
(3, 85.00, 0.00, 95, 'Kandungan nutrisi pakan aman', '2026-03-03', 3, 3);                                       

INSERT INTO batch_limbah (id_batch, jumlah, tanggal_masuk, status, gambar_barang, keterangan, pabrik_id_pabrik, jadwal_pengangkutan_id_jadwal) VALUES
(2, 15.00, '2026-03-03', 'Selesai', NULL, 'Reproduksi - Sisa Gagal produksi Briket Maret', 1, NULL);

INSERT INTO distribusi (id_distribusi, jumlah_produk, tanggal_distribusi, status, produk_id_produk, penerima_id_penerima) VALUES
(1, 40.00, '2026-03-07', 'Selesai', 1, 1), 
(2, 50.00, '2026-03-09', 'Selesai', 2, 2),  
(3, 55.00, '2026-03-10', 'Selesai', 3, 3),
(4, 30.00, '2026-03-15', 'Selesai', 1, 4), 
(5, 40.00, '2026-03-19', 'Selesai', 2, 6),  
(6, 30.00, '2026-03-19', 'Selesai', 3, 5);

-- --- SIKLUS II ---
INSERT INTO jadwal_pengangkutan (id_jadwal, tanggal_pengangkutan, status, catatan, petugas_id_petugas, kendaraan_id_kendaraan) VALUES
(2, '2026-06-01', 'Selesai', 'Ambil ampas tebu berkala PG Semboro', 2, 2);

INSERT INTO batch_limbah (id_batch, jumlah, tanggal_masuk, status, gambar_barang, keterangan, pabrik_id_pabrik, jadwal_pengangkutan_id_jadwal) VALUES
(3, 300.00, '2026-06-01', 'Selesai', 'ampas2.png', 'Ampas Tebu Utama Juni', 2, 2);

INSERT INTO produksi (id_produksi, jumlah_bahan, jumlah_hasil, biaya_produksi, tanggal_produksi, status, batch_limbah_id_batch, pengguna_id_pengguna, produk_id_produk) VALUES
(4, 15.00, 15.00, 50000.00, '2026-06-02', 'Selesai', 2, 2, 1),   
(5, 100.00, 90.00, 400000.00, '2026-06-02', 'Selesai', 3, 2, 1), 
(6, 100.00, 80.00, 300000.00, '2026-06-02', 'Selesai', 3, 2, 2), 
(7, 100.00, 90.00, 500000.00, '2026-06-02', 'Selesai', 3, 2, 3); 

INSERT INTO kontrol_kualitas (id_kontrol, jumlah_lolos, jumlah_gagal, nilai_kualitas, catatan, tanggal_pemeriksaan, pengguna_id_pengguna, produksi_id_produksi) VALUES
(4, 15.00, 0.00, 100, 'Briket hasil reproduksi Maret sukses total', '2026-06-03', 3, 4), 
(5, 90.00, 0.00, 98, 'Briket utama Juni padat dan kering', '2026-06-03', 3, 5),          
(6, 80.00, 0.00, 90, 'Kompos utama Juni lolos uji', '2026-06-03', 3, 6),                
(7, 90.00, 0.00, 92, 'Pakan utama Juni lolos uji', '2026-06-03', 3, 7);                

INSERT INTO distribusi (id_distribusi, jumlah_produk, tanggal_distribusi, status, produk_id_produk, penerima_id_penerima) VALUES
(7, 40.00, '2026-06-10', 'Selesai', 1, 1), 
(8, 50.00, '2026-06-11', 'Selesai', 2, 2),  
(9, 55.00, '2026-06-14', 'Selesai', 3, 3),
(10, 65.00, '2026-06-15', 'Selesai', 1, 4), 
(11, 30.00, '2026-06-21', 'Selesai', 2, 6),  
(12, 35.00, '2026-06-21', 'Selesai', 3, 5);

-- =========================================================================
-- 6. VIEWS CREATION (Diperbaiki dari Typo bawaan)
-- =========================================================================
CREATE OR REPLACE VIEW v_grid_batch_limbah AS
SELECT 
    b.id_batch,
    b.pabrik_id_pabrik AS id_pabrik,
    b.jumlah AS volume_kg,
    b.tanggal_masuk,
    b.status AS status_batch,
    b.keterangan,
    p.nama_pabrik,
    p.alamat AS alamat_pabrik,
    p.no_telepon AS kontak_pabrik
FROM batch_limbah b
LEFT JOIN pabrik p ON b.pabrik_id_pabrik = p.id_pabrik;

CREATE OR REPLACE VIEW v_grid_jadwal_pengangkutan AS
SELECT 
    j.id_jadwal,
    j.petugas_id_petugas AS id_petugas,     
    j.kendaraan_id_kendaraan AS id_kendaraan, 
    j.tanggal_pengangkutan,
    j.status AS status_pengangkutan,
    j.catatan,
    pt.nama_petugas AS nama_driver,
    pt.no_telepon AS kontak_driver,
    k.nama_kendaraan,
    k.kapasitas AS kapasitas_maksimal
FROM jadwal_pengangkutan j
LEFT JOIN petugas pt ON j.petugas_id_petugas = pt.id_petugas
LEFT JOIN kendaraan k ON j.kendaraan_id_kendaraan = k.id_kendaraan;

CREATE OR REPLACE VIEW v_grid_distribusi AS
SELECT 
    d.id_distribusi,
    d.produk_id_produk AS id_produk,
    d.penerima_id_penerima AS id_penerima,
    d.tanggal_distribusi,
    d.jumlah_produk AS jumlah_keluar_kg,
    d.status AS status_distribusi,
    p.nama_produk,
    p.satuan,
    pn.nama_penerima AS nama_distributor,
    pn.alamat AS alamat_tujuan
FROM distribusi d
LEFT JOIN produk p ON d.produk_id_produk = p.id_produk
LEFT JOIN penerima pn ON d.penerima_id_penerima = pn.id_penerima;

CREATE OR REPLACE VIEW v_grid_produksi AS
SELECT 
    p.id_produksi,
    p.batch_limbah_id_batch AS id_batch_asal,
    p.produk_id_produk AS id_produk,
    p.pengguna_id_pengguna AS id_pengguna,
    pb.nama_pabrik AS asal_pabrik_limbah,
    p.tanggal_produksi,
    p.jumlah_bahan AS bahan_baku_kg,
    p.jumlah_hasil AS target_hasil_kg,
    p.biaya_produksi,
    p.status AS status_produksi,
    pr.nama_produk,
    pr.gambar_produk
FROM produksi p
LEFT JOIN batch_limbah b ON p.batch_limbah_id_batch = b.id_batch
LEFT JOIN pabrik pb ON b.pabrik_id_pabrik = pb.id_pabrik
LEFT JOIN produk pr ON p.produk_id_produk = pr.id_produk;

CREATE OR REPLACE VIEW v_grid_kontrol_kualitas AS
SELECT 
    qc.id_kontrol,
    qc.produksi_id_produksi,  
    qc.pengguna_id_pengguna,  
    pd.nama_produk AS nama_produk,
    qc.tanggal_pemeriksaan,
    qc.jumlah_lolos,
    qc.jumlah_gagal,
    (qc.jumlah_lolos + qc.jumlah_gagal) AS total_diperiksa,
    qc.catatan
FROM kontrol_kualitas qc
LEFT JOIN produksi pr ON qc.produksi_id_produksi = pr.id_produksi
LEFT JOIN produk pd ON pr.produk_id_produk = pd.id_produk;

-- =========================================================================
-- 7. STORED PROCEDURES & FUNCTIONS CREATION
-- =========================================================================
CREATE OR REPLACE PROCEDURE sp_atur_status_jadwal(
    p_id_jadwal INT,
    p_status_baru enum_status_jadwal
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_batch INT;
BEGIN
    SELECT id_batch INTO v_id_batch
    FROM batch_limbah
    WHERE jadwal_pengangkutan_id_jadwal = p_id_jadwal;

    IF v_id_batch IS NULL THEN
        RAISE EXCEPTION 'Batch limbah untuk jadwal ID % tidak ditemukan.', p_id_jadwal;
    END IF;

    UPDATE jadwal_pengangkutan
    SET status = p_status_baru
    WHERE id_jadwal = p_id_jadwal;

    IF p_status_baru = 'Selesai'::enum_status_jadwal THEN
        UPDATE batch_limbah
        SET status = 'Siap Pakai'::enum_status_batch
        WHERE id_batch = v_id_batch;
    ELSIF p_status_baru = 'Diproses'::enum_status_jadwal THEN
        UPDATE batch_limbah
        SET status = 'Diproses'::enum_status_batch
        WHERE id_batch = v_id_batch;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_atur_status_produksi(
    p_id_produksi INT,
    p_status_baru enum_status_produksi
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_batch INT;
BEGIN
    SELECT batch_limbah_id_batch INTO v_id_batch
    FROM produksi
    WHERE id_produksi = p_id_produksi;

    IF v_id_batch IS NULL THEN
        RAISE EXCEPTION 'Data produksi dengan ID % tidak ditemukan.', p_id_produksi;
    END IF;

    UPDATE produksi
    SET status = p_status_baru
    WHERE id_produksi = p_id_produksi;

    IF p_status_baru = 'Diproses'::enum_status_produksi THEN
        UPDATE batch_limbah
        SET status = 'Diproses'::enum_status_batch
        WHERE id_batch = v_id_batch;
    ELSIF p_status_baru = 'Selesai'::enum_status_produksi THEN
        UPDATE batch_limbah
        SET status = 'Diproses'::enum_status_batch
        WHERE id_batch = v_id_batch;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_finalisasi_qc_total(
    p_id_kontrol INT,
    p_id_produksi INT,
    p_jumlah_lolos DECIMAL(10,2),
    p_jumlah_gagal DECIMAL(10,2),
    p_nilai_kualitas INT,
    p_tanggal_pemeriksaan DATE,
    p_catatan TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_batch INT;
    v_id_produk INT;
    v_total_produksi_awal DECIMAL(10,2);
    v_total_diperiksa_user DECIMAL(10,2);
    v_status_produksi enum_status_produksi;
BEGIN
    SELECT 
        batch_limbah_id_batch,
        jumlah_hasil,
        produk_id_produk,
        status
    INTO 
        v_id_batch,
        v_total_produksi_awal,
        v_id_produk,
        v_status_produksi
    FROM produksi
    WHERE id_produksi = p_id_produksi;

    IF v_id_batch IS NULL THEN
        RAISE EXCEPTION 'Data produksi dengan ID % tidak ditemukan.', p_id_produksi;
    END IF;

    IF v_status_produksi = 'Selesai'::enum_status_produksi THEN
        RAISE EXCEPTION 'Produksi ID % sudah selesai dan tidak dapat difinalisasi ulang.', p_id_produksi;
    END IF;

    IF p_nilai_kualitas < 0 OR p_nilai_kualitas > 100 THEN
        RAISE EXCEPTION 'Nilai kualitas harus berada antara 0 sampai 100.';
    END IF;

    v_total_diperiksa_user := p_jumlah_lolos + p_jumlah_gagal;

    IF v_total_diperiksa_user <> v_total_produksi_awal THEN
        RAISE EXCEPTION 
        'Total QC tidak sesuai. Jumlah hasil produksi: %, total diperiksa: %',
        v_total_produksi_awal,
        v_total_diperiksa_user;
    END IF;

    UPDATE kontrol_kualitas
    SET 
        jumlah_lolos = p_jumlah_lolos,
        jumlah_gagal = p_jumlah_gagal,
        nilai_kualitas = p_nilai_kualitas,
        tanggal_pemeriksaan = p_tanggal_pemeriksaan,
        catatan = p_catatan
    WHERE id_kontrol = p_id_kontrol
      AND produksi_id_produksi = p_id_produksi;

    IF NOT FOUND THEN
        RAISE EXCEPTION 
        'Data kontrol kualitas ID % untuk produksi ID % tidak ditemukan.',
        p_id_kontrol,
        p_id_produksi;
    END IF;

    UPDATE produk
    SET stok = stok + p_jumlah_lolos
    WHERE id_produk = v_id_produk;

    IF p_jumlah_gagal > 0 THEN
        INSERT INTO batch_limbah
        (jumlah, tanggal_masuk, status, gambar_barang, keterangan, pabrik_id_pabrik, jadwal_pengangkutan_id_jadwal)
        VALUES
        (p_jumlah_gagal, CURRENT_DATE, 'Siap Pakai'::enum_status_batch, NULL, 'Produk kualitas gagal - Antrean Reproduksi', 1, NULL);
    END IF;

    UPDATE produksi
    SET status = 'Selesai'::enum_status_produksi
    WHERE id_produksi = p_id_produksi;

    IF NOT EXISTS (
        SELECT 1 
        FROM produksi 
        WHERE batch_limbah_id_batch = v_id_batch 
          AND status <> 'Selesai'::enum_status_produksi
    ) THEN
        UPDATE batch_limbah
        SET status = 'Selesai'::enum_status_batch
        WHERE id_batch = v_id_batch;
    ELSE
        UPDATE batch_limbah
        SET status = 'Diproses'::enum_status_batch
        WHERE id_batch = v_id_batch;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION fn_laporan_operasional_periode(p_awal DATE, p_akhir DATE)
RETURNS TABLE (
    kategori_operasional VARCHAR,
    nama_item VARCHAR,
    total DECIMAL(12,2),
    keterangan VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    
    SELECT 
        '1. BAHAN BAKU'::VARCHAR,
        pb.nama_pabrik::VARCHAR,
        SUM(b.jumlah)::DECIMAL(12,2),
        'Limbah Masuk ke Gudang'::VARCHAR
    FROM batch_limbah b
    JOIN pabrik pb ON b.pabrik_id_pabrik = pb.id_pabrik
    WHERE b.tanggal_masuk BETWEEN p_awal AND p_akhir 
    GROUP BY pb.nama_pabrik

    UNION ALL

    SELECT 
        '2. PRODUKSI & KUALITAS (PROSES)'::VARCHAR,
        COALESCE(p.nama_produk, 'TOTAL HASIL PRODUKSI PERIODE INI')::VARCHAR,
        SUM(pr.jumlah_hasil)::DECIMAL(12,2),
        CONCAT(
            'Lolos (Siap Jual): ', COALESCE(SUM(qc_sub.tot_lolos), 0), ' kg ',
            'Gagal (Reproduksi): ', COALESCE(SUM(qc_sub.tot_gagal), 0), ' kg'
        )::VARCHAR
    FROM produksi pr
    JOIN produk p ON pr.produk_id_produk = p.id_produk
    LEFT JOIN (
        SELECT 
            produksi_id_produksi, 
            SUM(jumlah_lolos) AS tot_lolos, 
            SUM(jumlah_gagal) AS tot_gagal
        FROM kontrol_kualitas
        GROUP BY produksi_id_produksi
    ) qc_sub ON qc_sub.produksi_id_produksi = pr.id_produksi
    WHERE pr.tanggal_produksi BETWEEN p_awal AND p_akhir 
    GROUP BY ROLLUP(p.nama_produk)

    UNION ALL

    SELECT 
        '3. DISTRIBUSI'::VARCHAR,
        'Total Distribusi / Barang Keluar'::VARCHAR,
        SUM(d.jumlah_produk)::DECIMAL(12,2),
        'Jumlah Barang Keluar Periode Ini'::VARCHAR
    FROM distribusi d
    WHERE d.tanggal_distribusi BETWEEN p_awal AND p_akhir 

    UNION ALL

    SELECT 
        '4. RIWAYAT PERUBAHAN'::VARCHAR,
        COALESCE(r.nama_tabel, 'TOTAL LOG AKTIVITAS DATA')::VARCHAR,
        COUNT(*)::DECIMAL(12,2),
        'Aktivitas manipulasi data (INSERT/UPDATE/DELETE)'::VARCHAR
    FROM riwayat_perubahan r
    WHERE r.tanggal_perubahan::DATE BETWEEN p_awal AND p_akhir
    GROUP BY ROLLUP(r.nama_tabel);

END;
$$ LANGUAGE plpgsql;

-- =========================================================================
-- 8. PENGUJIAN QUERY & PROSEDUR (DITUTUP DENGAN SELECT LAPORAN)
-- =========================================================================
SELECT * FROM fn_laporan_operasional_periode('2026-01-01', '2026-12-31');