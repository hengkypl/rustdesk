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

/// Nama internal aplikasi. `lang::translate` menyulih kata "RustDesk" di seluruh
/// teks antarmuka dengan nama ini, jadi harus enak dibaca di tengah kalimat.
pub const APP_NAME: &str = "Elang";

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

    let mut data: HashMap<String, Value> = HashMap::new();
    data.insert(
        "app-name".to_string(),
        Value::String(APP_NAME.to_string()),
    );
    data.insert("default-settings".to_string(), Value::Object(defaults));

    crate::common::apply_custom_client_config(data);
}
