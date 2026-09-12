// Identitas merek Elang Remote Desktop.
//
// RustDesk sudah punya pipeline branding sendiri (`common::read_custom_client`),
// tetapi pipeline itu hanya menerima berkas `custom.txt` yang ditandatangani
// dengan kunci privat milik RustDesk (jalur generator berbayar mereka). Karena
// kita membangun dari source, identitas dipatok langsung di sini lalu dialirkan
// ke pipeline yang sama lewat `common::apply_custom_client_config` — hasilnya
// identik, tanpa berkas tambahan di samping .exe.
//
// Nama internal WAJIB cocok dengan [a-zA-Z0-9-]+ (lihat
// `platform::windows::validate_install_app_name`): dipakai sebagai nama folder
// instalasi, nama service Windows, dan folder konfigurasi. Nama merek lengkap
// "Elang Remote Desktop" tampil lewat metadata .exe dan judul jendela.

use hbb_common::config::keys;
use serde_json::Value;
use std::collections::HashMap;

/// Nama internal aplikasi: nama berkas .exe, folder instalasi, nama service
/// Windows, folder konfigurasi, dan skema URL sekaligus. WAJIB cocok dengan
/// [a-zA-Z0-9-]+ (lihat `platform::windows::validate_install_app_name`) -
/// garis bawah DITOLAK, jadi "Elang_RD" tidak bisa dipakai.
///
/// Nama .exe hasil build wajib sama persis dengan nilai ini; lihat BINARY_NAME
/// di flutter/windows/CMakeLists.txt dan komentar di sana.
pub const APP_NAME: &str = "ElangRD";

/// Nama merek untuk dibaca manusia. Dipakai di teks antarmuka dan judul
/// jendela, supaya kalimatnya berbunyi "Elang Remote Desktop" dan bukan
/// "ElangRD" yang kaku. Bebas spasi karena tidak pernah jadi nama berkas.
pub const DISPLAY_NAME: &str = "Elang Remote Desktop";

/// Server rendezvous/relay milik sendiri (hbbs/hbbr di box PBX).
pub const RENDEZVOUS_SERVER: &str = "103.150.84.246";

/// Kunci publik server di atas (`/opt/rustdesk-server/id_ed25519.pub`).
/// Tanpa ini client menolak menyambung ke server kita.
pub const RENDEZVOUS_PUB_KEY: &str = "o4M3up98aSY8H7B8LkoHj6iL8FTT3RLJRjuyyQB+J6E=";

/// Terapkan identitas Elang. Dipanggil dari `common::load_custom_client()`
/// sehingga ikut terpakai di semua titik start (core_main, flutter_ffi, service).
pub fn apply_brand() {
    // Dipasang sebagai "default-settings", bukan "override-settings", supaya
    // pengguna tetap bisa menunjuk server lain bila memang diperlukan.
    let mut defaults = serde_json::Map::new();
    defaults.insert(
        keys::OPTION_CUSTOM_RENDEZVOUS_SERVER.to_string(),
        Value::String(RENDEZVOUS_SERVER.to_string()),
    );
    defaults.insert(
        keys::OPTION_KEY.to_string(),
        Value::String(RENDEZVOUS_PUB_KEY.to_string()),
    );

    // Bahasa dikunci ke Indonesia. src/lang/id.rs sudah disediakan RustDesk,
    // jadi tidak ada yang perlu diterjemahkan sendiri.
    defaults.insert("lang".to_string(), Value::String("id".to_string()));

    // Tab Jaringan disembunyikan: alamat server, relay, dan kunci sudah
    // dipatok di atas, jadi kolom itu hanya membingungkan pengguna.
    defaults.insert(
        "hide-network-settings".to_string(),
        Value::String("Y".to_string()),
    );

    // Tulisan "Didukung oleh RustDesk" di pojok kiri atas beranda dimatikan.
    // WAJIB di sini, bukan sebagai kunci tingkat-atas: kunci tingkat-atas masuk
    // ke HARD_SETTINGS, sedangkan `loadPowered` membacanya lewat
    // `mainGetBuildinOption` yang hanya melihat BUILTIN_SETTINGS - dan hanya
    // kunci di KEYS_BUILDIN_SETTINGS yang dialirkan ke sana.
    defaults.insert(
        "hide-powered-by-me".to_string(),
        Value::String("Y".to_string()),
    );

    // Password sekali-pakai berisi ANGKA SAJA. Kombinasi huruf besar/kecil
    // menyusahkan pengguna saat mendiktekan lewat telepon/WA, padahal tujuan
    // produk ini justru untuk meremote orang awam. Dipasang sebagai
    // "override-settings" supaya terkunci (tidak bisa dimatikan dari menu);
    // panjangnya tetap mengikuti `temporary-password-length` (bawaan 6 digit).
    let mut overrides = serde_json::Map::new();
    overrides.insert(
        keys::OPTION_ALLOW_NUMERNIC_ONE_TIME_PASSWORD.to_string(),
        Value::String("Y".to_string()),
    );

    let mut data: HashMap<String, Value> = HashMap::new();
    data.insert(
        "app-name".to_string(),
        Value::String(APP_NAME.to_string()),
    );
    // Kunci di luar "default-settings"/"override-settings" masuk ke HARD_SETTINGS.
    // Akun RustDesk tidak dipakai produk ini, jadi tab Akun dimatikan.
    data.insert(
        "disable-account".to_string(),
        Value::String("Y".to_string()),
    );
    // Nama tampilan dibaca lewat HARD_SETTINGS oleh `get_app_display_name()`
    // (teks antarmuka) dan `mainGetHardOption` (judul jendela).
    data.insert(
        "app-display-name".to_string(),
        Value::String(DISPLAY_NAME.to_string()),
    );
    data.insert("default-settings".to_string(), Value::Object(defaults));
    data.insert("override-settings".to_string(), Value::Object(overrides));

    crate::common::apply_custom_client_config(data);
}
