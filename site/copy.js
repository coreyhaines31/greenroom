// Copy buttons for blocks marked data-copy-target="<id>".
(() => {
  document.querySelectorAll("[data-copy-target]").forEach((button) => {
    const label = button.textContent;
    button.addEventListener("click", async () => {
      const target = document.getElementById(button.dataset.copyTarget);
      try {
        await navigator.clipboard.writeText(target.textContent);
        button.textContent = "Copied";
      } catch {
        const range = document.createRange();
        range.selectNodeContents(target);
        getSelection().removeAllRanges();
        getSelection().addRange(range);
        button.textContent = "Press ⌘C";
      }
      setTimeout(() => (button.textContent = label), 1800);
    });
  });
})();
