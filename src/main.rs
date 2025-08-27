use anyhow::{bail, Context, Result};
use wasmtime::{Engine, Linker, Module, Store};
use wasi_common::sync::WasiCtxBuilder;
use std::env;

fn main() -> Result<()> {
    let engine = Engine::default();
    let mut linker = Linker::new(&engine);
    wasmtime_wasi::add_to_linker(&mut linker, |s| s)?;

    let wasi = WasiCtxBuilder::new()
        .inherit_stdio()
        .inherit_args()?
        .inherit_env()? 
        .build();

    let mut store = Store::new(&engine, wasi);

    let module = Module::from_file(&engine, "plugin.wasm")?;
    let instance = linker.instantiate(&mut store, &module)?;

    let mut args = env::args().skip(1);
    let mode = args.next().unwrap_or_else(|| "all".to_string());

    match mode.as_str() {
        "mandelbrot" => {
            let run = instance.get_typed_func::<(), ()>(&mut store, "run")?;
            run.call(&mut store, ())?;
        }
        "add" => {
            let a: i32 = args
                .next()
                .context("usage: plug add <a> <b>")?
                .parse()
                .context("invalid integer for <a>")?;
            let b: i32 = args
                .next()
                .context("usage: plug add <a> <b>")?
                .parse()
                .context("invalid integer for <b>")?;
            let add = instance.get_typed_func::<(i32, i32), i32>(&mut store, "add")?;
            let sum = add.call(&mut store, (a, b))?;
            println!("add({}, {}) -> {}", a, b, sum);
        }
        "fib" => {
            let n: u32 = args
                .next()
                .context("usage: plug fib <n>")?
                .parse()
                .context("invalid integer for <n>")?;
            let fib = instance.get_typed_func::<(u32,), u64>(&mut store, "fib")?;
            let f = fib.call(&mut store, (n,))?;
            println!("fib({}) -> {}", n, f);
        }
        "all" | "run" => {
            let run = instance.get_typed_func::<(), ()>(&mut store, "run")?;
            run.call(&mut store, ())?;
            let add = instance.get_typed_func::<(i32, i32), i32>(&mut store, "add")?;
            let sum = add.call(&mut store, (20, 22))?;
            println!("add(20, 22) -> {}", sum);
            let fib = instance.get_typed_func::<(u32,), u64>(&mut store, "fib")?;
            let f10 = fib.call(&mut store, (10,))?;
            println!("fib(10) -> {}", f10);
        }
        other => bail!(
            "unknown mode '{}'. Use one of: mandelbrot | add <a> <b> | fib <n> | all",
            other
        ),
    }

    println!("WASM plugin executed successfully!");

    Ok(())
}
