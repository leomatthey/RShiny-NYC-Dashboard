/* ============================================================================
   NYC Traffic Accidents 2020 — Custom JavaScript
   ============================================================================ */

/* -- Crash Count Badge Handler --------------------------------------------- */
$(document).ready(function() {

  // Handler: update the crash count badge from server
  Shiny.addCustomMessageHandler("update_crash_count", function(count) {
    var badge = document.getElementById("crash-count-badge");
    if (!badge) return;

    var valueEl = badge.querySelector(".badge-value");
    if (!valueEl) return;

    // Format number with commas
    var formatted = Number(count).toLocaleString("en-US");
    valueEl.textContent = formatted;

    // Trigger pulse animation
    badge.classList.remove("pulse");
    void badge.offsetWidth; // force reflow
    badge.classList.add("pulse");
  });

  /* -- Tab Transition Animation -------------------------------------------- */
  // Re-trigger fade animation when tabs change
  $(document).on("shown.bs.tab", 'a[data-toggle="tab"]', function() {
    var target = $(this).attr("href") || $(this).data("target");
    if (target) {
      var pane = $(target);
      pane.css("animation", "none");
      void pane[0].offsetWidth;
      pane.css("animation", "fadeSlideIn 0.4s ease-out");
    }
  });

  /* -- Plotly Resize on Tab Switch ----------------------------------------- */
  // Plotly charts need a resize trigger when their tab becomes visible
  $(document).on("shown.bs.tab", 'a[data-toggle="tab"]', function() {
    setTimeout(function() {
      $(window).trigger("resize");
    }, 100);
  });

});
