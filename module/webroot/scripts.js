let running = false;
const modulePath = "/data/adb/modules/honor-systemmanager-patch";
const profiles = ["security", "background", "powerkit"];

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

function setProfileStatus(profile, mode) {
  const pill = document.querySelector(`[data-status="${profile}"]`);
  if (!pill) return;
  pill.textContent = mode;
  pill.dataset.mode = mode;
}

async function readProfileMode(profile) {
  const mode = await exec(`cat ${modulePath}/modes/${profile} 2>/dev/null || cat ${modulePath}/mode 2>/dev/null || echo unknown`);
  return mode.trim();
}

async function refreshModes() {
  await Promise.all(
    profiles.map(async (profile) => {
      try {
        setProfileStatus(profile, await readProfileMode(profile));
      } catch {
        setProfileStatus(profile, "unknown");
      }
    }),
  );
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
    document.getElementById("version").textContent = version.trim();
  } catch {
    document.getElementById("version").textContent = "module status unavailable";
  }
  refreshModes();
}

document.addEventListener("DOMContentLoaded", () => {
  document.getElementById("status").addEventListener("click", () => {
    run("test all profile status", `MODDIR=${modulePath} sh ${modulePath}/common/status.sh all`);
  });
  document.querySelectorAll("button[data-mode][data-profile]").forEach((button) => {
    button.addEventListener("click", async () => {
      const mode = button.dataset.mode;
      const profile = button.dataset.profile;
      await run(
        `${mode} ${profile}`,
        `mkdir -p ${modulePath}/modes && echo ${mode} > ${modulePath}/modes/${profile} && MODDIR=${modulePath} sh ${modulePath}/common/patch.sh ${mode} ${profile} && MODDIR=${modulePath} sh ${modulePath}/common/status.sh ${profile}`,
      );
      refreshModes();
    });
  });
  document.getElementById("clear").addEventListener("click", () => {
    output().textContent = "";
  });
  loadVersion();
});
