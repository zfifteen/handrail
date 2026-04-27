#!/usr/bin/env node

console.log(JSON.stringify({ type: "thread.started", thread_id: "fake-thread" }));
console.log(JSON.stringify({ type: "item.completed", item: { type: "agent_message", text: `args:${process.argv.slice(2).join("|")}` } }));
