let running = false;
const modulePath = "/data/adb/modules/honor-systemmanager-patch";

function output() {
  return document.getElementById("output");
}

function append(text) {
  output().textContent += text;
  if (!text.endsWith("\n")) output().textContent += "\n";
  output().scrollTop = output().scrollHeight;
}

function exec(command) {
  return new Promise((resolve, reject) => {
    const callback = `cb_${Date.now()}_${Math.random().toString(16).slice(2)}`;
    window[callback] = (errno, stdout, stderr) => {
      delete window[callback];
      if (errno !== 0) {
        reject(new Error(stderr || `Command failed: ${errno}`));
        return;
      }
      resolve(stdout);
    };
    try {
      ksu.exec(command, "{}", callback);
    } catch (error) {
      delete window[callback];
      reject(error);
    }
  });
}

async function run(label, command) {
  if (running) return;
  running = true;
  append(`$ ${label}`);
  try {
    const stdout = await exec(command);
    append(stdout.trim() ? stdout : "(no output)");
  } catch (error) {
    append(`ERROR: ${error.message}`);
  }
  append("");
  running = false;
}

async function loadVersion() {
  try {
    const version = await exec(`grep '^version=' ${modulePath}/module.prop | cut -d= -f2`);
    const mode = await exec(`cat ${modulePath}/mode 2>/dev/null || echo unknown`);
    document.getElementById("version").textContent = `${version.trim()} · mode: ${mode.trim()}`;
  } catch {
    document.getElementById("version").textContent = "module status unavailable";
  }
}

document.addEventListener("DOMContentLoaded", () => {
  document.getElementById("status").addEventListener("click", () => {
    run("test current service status", `MODDIR=${modulePath} sh ${modulePath}/common/status.sh`);
  });
  document.getElementById("block").addEventListener("click", async () => {
    await run("block services", `echo block > ${modulePath}/mode && MODDIR=${modulePath} sh ${modulePath}/common/patch.sh block && MODDIR=${modulePath} sh ${modulePath}/common/status.sh`);
    loadVersion();
  });
  document.getElementById("restore").addEventListener("click", async () => {
    await run("restore services", `echo restore > ${modulePath}/mode && MODDIR=${modulePath} sh ${modulePath}/common/patch.sh restore && MODDIR=${modulePath} sh ${modulePath}/common/status.sh`);
    loadVersion();
  });
  document.getElementById("clear").addEventListener("click", () => {
    output().textContent = "";
  });
  loadVersion();
});
