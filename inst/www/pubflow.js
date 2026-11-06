/*
 * pubflow parameter UI:
 * - visual-target resolution for selectize inputs;
 * - Shiny custom-message handlers 'pubflow:triggerClassAttrib',
 *   'pubflow:showInputInlineMessage', 'pubflow:syncInputValue' and
 *   'pubflow:setInputAttrib';
 * - description tooltips with show delay and auto-hide.
 *
 * Works with Bootstrap 3 ($.fn.tooltip) and Bootstrap 5
 * (bootstrap.Tooltip); tooltips are created when needed, so they also work
 * for inputs inserted later (renderUI).
 */
(function($)
{
    'use strict';

    if (!$) {
        return;
    }

    // ---------------------------------------------------------------------
    // Bootstrap 3/5 tooltip adapter
    // ---------------------------------------------------------------------

    function hasBootstrap5()
    {
        return !!(window.bootstrap && window.bootstrap.Tooltip &&
            typeof window.bootstrap.Tooltip.getOrCreateInstance === 'function');
    }

    /**
     * Create the tooltip of an element unless it exists.
     *
     * @param {HTMLElement} el - Element the tooltip belongs to.
     * @param {object} config - Bootstrap tooltip options.
     * @returns {boolean} true if the element has a tooltip.
     */
    function tooltipCreate(el, config)
    {
        if (hasBootstrap5()) {
            return !!window.bootstrap.Tooltip.getOrCreateInstance(el, config);
        }
        var $el = $(el);
        if (typeof $el.tooltip !== 'function') {
            return false;
        }
        if (!$el.data('bs.tooltip')) {
            $el.tooltip(config);
        }
        return !!$el.data('bs.tooltip');
    }

    /**
     * Call a tooltip method ('show', 'hide' or 'dispose') if the element has
     * a tooltip.
     */
    function tooltipCall(el, method)
    {
        if (hasBootstrap5()) {
            var tip = window.bootstrap.Tooltip.getInstance(el);
            if (tip) {
                tip[method]();
            }
            return;
        }
        var $el = $(el);
        if (typeof $el.tooltip !== 'function' || !$el.data('bs.tooltip')) {
            return;
        }
        try {
            $el.tooltip(method);
        } catch (e) {
            if (method === 'dispose') {
                try {
                    $el.tooltip('destroy');     // Bootstrap 3
                } catch (ignore) {
                    // ignore bootstrap version differences
                }
            }
        }
    }

    function tooltipTemplate(cls)
    {
        return '<div class="tooltip ' + cls + '" role="tooltip">' +
            '<div class="tooltip-arrow"></div>' +
            '<div class="tooltip-inner"></div></div>';
    }

    function positiveNumber(x, fallback)
    {
        var ms = Number(x);
        return Number.isFinite(ms) && ms > 0 ? ms : fallback;
    }

    function clearTimer($el, key)
    {
        var timer = $el.data(key);
        if (timer) {
            window.clearTimeout(timer);
            $el.removeData(key);
        }
    }


    /**
     * Resolve the visible UI element used for feedback effects.
     *
     * For selectize-backed inputs this returns the visible selectize control;
     * otherwise it returns the original element wrapped in jQuery.
     *
     * @param {HTMLElement|null} el - Source DOM element from message id.
     * @returns {jQuery|null} jQuery-wrapped visual target element.
     */
    function pubflowResolveVisualTarget(el)
    {
        if (!el) {
            return null;
        }

        var $el = $(el);

        // For selectize inputs, target the visible control element.
        if (el.selectize && el.selectize.$control &&
            el.selectize.$control.length) {
            return el.selectize.$control;
        }

        var $selectizeInput = $el
            .siblings('.selectize-control')
            .find('.selectize-input')
            .first();
        if ($selectizeInput.length) {
            return $selectizeInput;
        }

        return $el;
    }


    // ---------------------------------------------------------------------
    // Custom message handlers
    // ---------------------------------------------------------------------

    /**
     * Trigger a temporary CSS class (and attributes) on a target element.
     *
     * @param {object} msg - Shiny custom-message payload.
     * @param {string} msg.id - DOM id of the element to animate.
     * @param {string} msg.what - CSS class to apply temporarily.
     * @param {object} [msg.attrib] - Attributes to set temporarily on the
     *   element and its visual target, e.g. {"aria-invalid": "true"}.
     * @param {number} [msg.timeout=3000] - Duration in milliseconds.
     * @returns {void}
     */
    function triggerClassAttrib(msg)
    {
        var el = document.getElementById(msg.id);
        var $target = pubflowResolveVisualTarget(el);
        if (!$target || !$target.length) {
            return;
        }
        var ms = positiveNumber(msg.timeout, 3000);
        var attrib = msg.attrib || {};
        var $all = $(el).add($target);

        clearTimer($target, 'pubflowClassTimer');
        $target.removeClass(msg.what);
        void $target[0].offsetWidth;    // restart the CSS animation
        $target.addClass(msg.what);
        $.each(attrib, function(name, value) {
            $all.attr(name, value);
        });

        $target.data('pubflowClassTimer', window.setTimeout(function() {
            $target.removeClass(msg.what);
            $.each(attrib, function(name) {
                $all.removeAttr(name);
            });
            $target.removeData('pubflowClassTimer');
        }, ms));
    }


    /**
     * Show a short-lived inline validation message anchored to an input.
     *
     * @param {object} msg - Shiny custom-message payload.
     * @param {string} msg.id - DOM id of the input element.
     * @param {string} msg.text - Message text rendered in the tooltip.
     * @param {number} [msg.timeout=3000] - Visibility duration in
     *   milliseconds.
     * @returns {void}
     */
    function showInputInlineMessage(msg)
    {
        if (!msg.id || !msg.text) {
            return;
        }
        var ms = positiveNumber(msg.timeout, 3000);

        var el = document.getElementById(msg.id);
        var $anchor = pubflowResolveVisualTarget(el);
        if (!$anchor || !$anchor.length) {
            return;
        }
        var anchorEl = $anchor[0];

        var clearTooltip = function() {
            tooltipCall(anchorEl, 'dispose');
            // Clean up a tooltip bound to the hidden select element.
            if (anchorEl !== el) {
                tooltipCall(el, 'dispose');
            }
        };

        clearTimer($anchor, 'pubflowInlineTooltipTimer');
        clearTooltip();

        var created = tooltipCreate(anchorEl, {
            title: msg.text,
            trigger: 'manual',
            container: 'body',
            animation: false,
            viewport: { selector: 'body', padding: 8 },     // Bootstrap 3
            placement: function() {
                var rect = anchorEl.getBoundingClientRect();
                var viewWidth = Math.max(
                    document.documentElement.clientWidth || 0,
                    window.innerWidth || 0
                );
                // Avoid left placement for side-by-side fields because it
                // can overlap neighboring inputs; fall back to top instead.
                return viewWidth - rect.right >= 320 ? 'right' : 'top';
            },
            html: false,
            template: tooltipTemplate('pubflow-input-inline-tooltip')
        });
        if (!created) {
            return;
        }
        tooltipCall(anchorEl, 'show');

        $anchor.data('pubflowInlineTooltipTimer', window.setTimeout(function() {
            clearTooltip();
            $anchor.removeData('pubflowInlineTooltipTimer');
        }, ms));
    }


    /**
     * Sync input values back to Shiny. With the default priority (not
     * 'event', which Shiny sends one value at a time), the inputs of a param
     * group reach the server in one message.
     *
     * @param {object} msg - Shiny custom-message payload.
     * @param {Array<{id: string, value: *}>} msg.inputs - Shiny input ids and
     *   the values to push into them.
     * @returns {void}
     */
    function syncInputValue(msg)
    {
        (msg.inputs || []).forEach(function(input) {
            if (input.id) {
                Shiny.setInputValue(input.id, input.value);
            }
        });
    }


    /**
     * Set or remove attributes of an input and its visual target.
     *
     * @param {object} msg - Shiny custom-message payload.
     * @param {string} msg.id - DOM id of the input element.
     * @param {object} msg.attrib - Attribute values; false or null removes
     *   the attribute.
     * @returns {void}
     */
    function setInputAttrib(msg)
    {
        var el = document.getElementById(msg.id);
        if (!el) {
            return;
        }
        var $all = $(el).add(pubflowResolveVisualTarget(el));
        $.each(msg.attrib || {}, function(name, value) {
            if (value === false || value === null) {
                $all.removeAttr(name);
            } else {
                $all.attr(name, value);
            }
        });
    }

    if (window.Shiny && typeof Shiny.addCustomMessageHandler === 'function') {
        Shiny.addCustomMessageHandler(
            'pubflow:triggerClassAttrib', triggerClassAttrib
        );
        Shiny.addCustomMessageHandler(
            'pubflow:showInputInlineMessage', showInputInlineMessage
        );
        Shiny.addCustomMessageHandler(
            'pubflow:syncInputValue', syncInputValue
        );
        Shiny.addCustomMessageHandler(
            'pubflow:setInputAttrib', setInputAttrib
        );
    }


    // ---------------------------------------------------------------------
    // Description tooltips
    // ---------------------------------------------------------------------

    /**
     * Tooltips of elements with class "pubflow-tooltip" (see the R function
     * .with_tooltip()): shown after the delay of `data-delay` (default
     * 1500 ms) while the mouse is over the element and at once when an
     * input in it gets the keyboard focus (not the focus of a click);
     * hidden on mouseleave, blur, click or Escape and after
     * `data-pubflow-tooltip-autohide-ms`. While a tooltip shown on focus is
     * open, it describes the focused element (`aria-describedby`).
     * The tooltip is created on first use with trigger 'manual', so it
     * works for elements inserted after page load and with Bootstrap 3 and
     * 5 alike.
     */
    var TOOLTIP_SELECTOR = '.pubflow-tooltip';
    var SHOW_TIMER = 'pubflowTooltipShowTimer';
    var HIDE_TIMER = 'pubflowTooltipAutohideTimer';
    var DESCRIBED = 'pubflowTooltipDescribed';
    var lastPointerDown = 0;

    function showDelay($el)
    {
        var delay = $el.attr('data-bs-delay') || $el.attr('data-delay');
        try {
            delay = JSON.parse(delay);
        } catch (e) {
            // a number or nothing
        }
        if (delay && typeof delay === 'object') {
            delay = delay.show;
        }
        return positiveNumber(delay, 1500);
    }

    function hideDescription(el)
    {
        var $el = $(el);
        clearTimer($el, SHOW_TIMER);
        clearTimer($el, HIDE_TIMER);
        // only an open tooltip (Bootstrap links it with aria-describedby):
        // Bootstrap 3 also ends the 'hide' of a closed one after its fade,
        // which would remove a tooltip shown in the meantime
        if ($el.attr('aria-describedby')) {
            tooltipCall(el, 'hide');
        }
        undescribe($el);
    }

    /**
     * Let the open tooltip of `$el` describe the focused element `target`
     * (Bootstrap links it to `$el` only).
     */
    function describe($el, target)
    {
        var tipId = $el.attr('aria-describedby');
        if (target && target !== $el[0] && tipId &&
            !target.hasAttribute('aria-describedby')) {
            target.setAttribute('aria-describedby', tipId);
            $el.data(DESCRIBED, target);
        }
    }

    /**
     * Undo describe(): the tooltip of `$el` no longer describes an element.
     */
    function undescribe($el)
    {
        var described = $el.data(DESCRIBED);
        if (described) {
            $el.removeData(DESCRIBED);
            described.removeAttribute('aria-describedby');
        }
    }

    /**
     * Show the tooltip of `el`; `target` (optional) is the focused element
     * it describes while it is open.
     */
    function showDescription(el, target)
    {
        var $el = $(el);
        if (!document.body.contains(el)) {
            return;
        }
        var created = tooltipCreate(el, {
            trigger: 'manual',
            container: 'body',
            placement: 'top',
            html: false,
            template: tooltipTemplate('pubflow-description-tooltip')
        });
        if (!created) {
            return;
        }
        tooltipCall(el, 'show');
        describe($el, target);
        var ms = positiveNumber(
            $el.attr('data-pubflow-tooltip-autohide-ms'), 0
        );
        if (ms > 0) {
            $el.data(HIDE_TIMER, window.setTimeout(function() {
                $el.removeData(HIDE_TIMER);
                tooltipCall(el, 'hide');
                undescribe($el);
            }, ms));
        }
    }

    $(document).on('mouseenter', TOOLTIP_SELECTOR, function()
    {
        var el = this;
        var $el = $(el);
        hideDescription(el);
        $el.data(SHOW_TIMER, window.setTimeout(function() {
            $el.removeData(SHOW_TIMER);
            showDescription(el);
        }, showDelay($el)));
    });

    $(document).on('mouseleave mousedown', TOOLTIP_SELECTOR, function()
    {
        hideDescription(this);
    });

    // Focus that moves within the element (e.g. between radio buttons)
    // keeps the tooltip.
    $(document).on('focusout', TOOLTIP_SELECTOR, function(event)
    {
        if (!event.relatedTarget || !this.contains(event.relatedTarget)) {
            hideDescription(this);
        }
    });

    // A focus that follows a click or tap shows no tooltip (the mouse has
    // its own). Not `:focus-visible`: browsers match it for text inputs
    // after a click. A tap focuses the input some 100 ms after pointerdown.
    var POINTER_FOCUS_MS = 1000;
    document.addEventListener('pointerdown', function()
    {
        lastPointerDown = Date.now();
    }, true);

    $(document).on('focusin', TOOLTIP_SELECTOR, function(event)
    {
        if (Date.now() - lastPointerDown < POINTER_FOCUS_MS) {
            return;
        }
        var $el = $(this);
        // Open already (hover, or focus moved within the element): keep it.
        // Bootstrap links an open tooltip with aria-describedby; showing it
        // again would hide it (Bootstrap 5).
        if ($el.attr('aria-describedby')) {
            undescribe($el);
            describe($el, event.target);
            return;
        }
        // no 'hide' before 'show': the end of its fade would remove the
        // tooltip just shown
        clearTimer($el, SHOW_TIMER);
        clearTimer($el, HIDE_TIMER);
        showDescription(this, event.target);
    });

    // A key ends the click or tap: the next focus (Tab) is the keyboard's.
    // Escape hides the open and pending tooltips, also those of the mouse.
    // Capture phase, as selectize stops the event.
    document.addEventListener('keydown', function(event)
    {
        lastPointerDown = 0;
        if (event.key !== 'Escape') {
            return;
        }
        $(TOOLTIP_SELECTOR).each(function()
        {
            var $el = $(this);
            if ($el.attr('aria-describedby') || $el.data(SHOW_TIMER)) {
                hideDescription(this);
            }
        });
    }, true);

    // A re-rendered parameter table must not leave tooltips behind.
    $(document).on('shiny:value', function(event)
    {
        if ($(event.target).hasClass('pubflow-params')) {
            $('.tooltip.pubflow-description-tooltip').remove();
        }
    });


    // ---------------------------------------------------------------------
    // "Advanced" blocks
    // ---------------------------------------------------------------------

    // Sliders measure their width when created; inside a closed <details>
    // block it is 0, so let them re-measure when the block opens. The
    // 'toggle' event does not bubble: listen in the capture phase.
    document.addEventListener('toggle', function(event)
    {
        var el = event.target;
        if (el && el.open && el.matches &&
            el.matches('details.pubflow-params-advanced')) {
            $(window).trigger('resize');
        }
    }, true);
})(window.jQuery);
