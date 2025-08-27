use anyhow::Result;
use wasmtime::{Engine, Linker, Module, Store};
use wasi_common::sync::WasiCtxBuilder;

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

    // Call the fun ASCII Mandelbrot demo
    let run = instance.get_typed_func::<(), ()>(&mut store, "run")?;
    run.call(&mut store, ())?;

    // Call typed functions exported by the plugin
    let add = instance.get_typed_func::<(i32, i32), i32>(&mut store, "add")?;
    let sum = add.call(&mut store, (20, 22))?;
    println!("add(20, 22) -> {}", sum);

    let fib = instance.get_typed_func::<(u32,), u64>(&mut store, "fib")?;
    let f10 = fib.call(&mut store, (10,))?;
    println!("fib(10) -> {}", f10);

    println!("WASM plugin executed successfully!");

    Ok(())
}
