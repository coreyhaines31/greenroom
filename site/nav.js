// Close the nav's Free tests menu on an outside click or Escape.
(() => {
  const menus = document.querySelectorAll("details.menu");
  if (!menus.length) return;
  document.addEventListener("click", (event) => {
    menus.forEach((menu) => { if (!menu.contains(event.target)) menu.open = false; });
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") menus.forEach((menu) => (menu.open = false));
  });
})();
