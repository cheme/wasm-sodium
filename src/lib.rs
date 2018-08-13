
// reexport sodiumoxide
#![feature(proc_macro, wasm_custom_section, wasm_import_module)]
#![feature(use_extern_macros)]
pub extern crate sodiumoxide;
extern crate wasm_bindgen;
extern crate libc_stub; // see comments on this crate for what this is
extern crate openssl;
 
use openssl::sha;
 
fn hashopenssl() {
    let mut hasher = sha::Sha256::new();
 
    hasher.update(b"Hello, ");
    hasher.update(b"world");
 
    let hash = hasher.finish();
    println!("Hashed \"Hello, world\" to {}", AsHex(hash.as_ref()));
}

use std::fmt::{self, Write};

use wasm_bindgen::prelude::*;

#[wasm_bindgen]
extern {
    #[wasm_bindgen(js_namespace = console)]
    fn log(a: &str);
}

macro_rules! console_log {
    ($($t:tt)*) => (log(&format!($($t)*)))
}

#[cfg(feature="wasm-tests")]
#[wasm_bindgen]
pub fn tests() {
  sodium_asym();
  hashopenssl();
}

fn sodium_asym() {
    sodiumoxide::init().unwrap();
use sodiumoxide::crypto::sign;
let (pk, sk) = sign::gen_keypair();
let data_to_sign = b"some data";
let signed_data = sign::sign(data_to_sign, &sk);
let verified_data = sign::verify(&signed_data, &pk).unwrap();
assert!(data_to_sign == &verified_data[..]);
let (pk, sk) = sign::gen_keypair();
let data_to_sign = b"some data";
let signature = sign::sign_detached(data_to_sign, &sk);
assert!(sign::verify_detached(&signature, data_to_sign, &pk));
console_log!("assert pass for sign sample");

}

#[wasm_bindgen]
pub fn run() {
    sodiumoxide::init().unwrap();

    // Generate some random bytes
    //
    // NB the random byte generator is very low quality, it's implemented in
    // the `libc-shim` crate via `read` currently.
    let bytes = sodiumoxide::randombytes::randombytes(10);
    console_log!("10 randomly generated bytes are {:?}", bytes);

    // Generate a sha256 digest
    let mut h = sodiumoxide::crypto::hash::sha256::State::new();
    h.update(b"Hello, World!");
    let digest = h.finalize();
    console_log!("sha256(\"Hello, World!\") = {}", AsHex(digest.as_ref()));
}

struct AsHex<'a>(&'a [u8]);

impl<'a> fmt::Display for AsHex<'a> {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        for &byte in self.0.iter() {
            f.write_char(btoc(byte >> 4))?;
            f.write_char(btoc(byte))?;
        }
        return Ok(());

        fn btoc(a: u8) -> char {
            let a = a & 0xf;
            match a {
                0...9 => (b'0' + a) as char,
                _ => (b'a' + a - 10) as char,
            }
        }
    }
}
