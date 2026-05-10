use std::env;
use std::fs;
use std::io::Write;
use std::path::Path;
use std::process::{ Command, Stdio };
use std::thread::sleep;
use std::time::Duration;

const PIF_TMP: &str = "/data/system/pif_tmp.apk";
const PIF_APK: &str = "/data/PIF.apk";

fn silent_kill(process: &str) {
    let _ = Command::new("killall")
        .arg(process)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}

fn rin_pif() {
    let url = "https://raw.githubusercontent.com/ryanistr/OemPorts10T-PIF-Forked/refs/heads/pif-apk/PIF.apk";

    let status = Command::new("rin")
        .args(
            &[
                "-k",
                "-s",
                "-4",
                "--resolve",
                "raw.githubusercontent.com:443:185.199.108.133",
                url,
                "-o",
                PIF_TMP,
            ]
        )
        .status();

    let mut success = false;
    if let Ok(st) = status {
        if st.success() {
            if let Ok(metadata) = fs::metadata(PIF_TMP) {
                if metadata.len() >= 1000 {
                    success = true;
                }
            }
        }
    }

    sleep(Duration::from_secs(1));
    if !success {
        retry_pif_if_fail();
    }
}

fn retry_pif_if_fail() {
    if let Ok(metadata) = fs::metadata(PIF_TMP) {
        if metadata.len() < 1000 {
            println!("Failed retrieving PIF.apk, retrying...");
            rin_pif();
        }
    } else {
        println!("Download failed, retrying...");
        rin_pif();
    }
}

fn fetch_pif() {
    loop {
        println!("Checking internet connection...");
        let mut child = Command::new("/vendor/bin/nc")
            .args(&["1.1.1.1", "80"])
            .stdin(Stdio::piped())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .expect("failed to spawn nc");
        if let Some(mut stdin) = child.stdin.take() {
            let _ = stdin.write_all(b"GET http://1.1.1.1 HTTP/1.0\n\n");
        }
        if let Ok(status) = child.wait() {
            if status.success() {
                println!("Connected to internet, fetching latest PIF.apk!");
                rin_pif();
                break;
            }
        }
        sleep(Duration::from_secs(2));
    }
}

fn md5sum(path: &str) -> Option<String> {
    let output = Command::new("/vendor/bin/md5sum").arg(path).output().ok()?;
    let text = String::from_utf8_lossy(&output.stdout);
    Some(text.split_whitespace().next()?.to_string())
}

fn main_logic() {
    fetch_pif();
    let pif_tmp_md5 = md5sum(PIF_TMP);
    let pif_md5 = md5sum(PIF_APK);

    if pif_tmp_md5 != pif_md5 && pif_tmp_md5.is_some() {
        println!("New Version Found! Installing latest PIF.apk");
        let _ = fs::copy(PIF_TMP, PIF_APK);
        let _ = Command::new("pm").args(&["install", PIF_APK]).status();
        silent_kill("com.google.android.gms.unstable");
        println!("PIF.apk updated!");
    } else {
        println!("Your PIF.apk version is already the latest one!");
    }

    if Path::new(PIF_TMP).exists() {
        let _ = fs::remove_file(PIF_TMP);
    }

    if !Path::new("/system/bin/pif-updater").exists() {
        let _ = Command::new("mount").args(&["-o", "remount,rw", "/"]).status();
        let _ = Command::new("ln")
            .args(&["-s", "/vendor/bin/oemports10t_PIF-updater", "/system/bin/pif-updater"])
            .status();
        let _ = Command::new("mount").args(&["-o", "remount,ro", "/"]).status();
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() > 1 {
        let mut i = 1;
        let mut executed_flag = false;

        while i < args.len() {
            if args[i] == "-p" {
                silent_kill("com.android.vending");
                silent_kill("com.google.android.gms.unstable");
                executed_flag = true;
            }
            i += 1;
        }

        if !executed_flag {
            main_logic();
        }
    } else {
        main_logic();
    }
}