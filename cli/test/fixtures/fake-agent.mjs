console.log(JSON.stringify({ type: "thread.started", thread_id: "fake-thread" }));
console.log(`prompt:${process.argv.slice(2).join(" ")}`);
