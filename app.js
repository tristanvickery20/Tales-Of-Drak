const buttons = document.querySelectorAll(".tabs button");
const screens = document.querySelectorAll(".screen");

buttons.forEach(button => {
  button.addEventListener("click", () => {
    buttons.forEach(b => b.classList.remove("active"));
    screens.forEach(s => s.classList.remove("active"));

    button.classList.add("active");
    document.getElementById(button.dataset.screen).classList.add("active");
  });
});

const classSelect = document.getElementById("classSelect");
const originSelect = document.getElementById("originSelect");
const summary = document.getElementById("characterSummary");

function updateSummary() {
  summary.textContent = `You are a ${originSelect.value} ${classSelect.value}.`;
}

if (classSelect && originSelect && summary) {
  classSelect.addEventListener("change", updateSummary);
  originSelect.addEventListener("change", updateSummary);
  updateSummary();
}

const encounterBtn = document.getElementById("encounterBtn");
const encounterText = document.getElementById("encounterText");

const encounters = [
  "3 cursed knights and 1 grave priest appear.",
  "A moon-beast stalks the party from the fog.",
  "The altar awakens and summons bone archers.",
  "A corrupted paladin challenges the group."
];

if (encounterBtn && encounterText) {
  encounterBtn.addEventListener("click", () => {
    const pick = encounters[Math.floor(Math.random() * encounters.length)];
    encounterText.textContent = pick;
  });
}