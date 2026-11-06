/*
 * pubflow document viewer (pub_viewer_ui()).
 *
 * The server renders the document and its table of contents; this script
 * - highlights the table of contents entry of the section being read
 *   (scrollspy), whether the page or the viewer scrolls;
 * - typesets math with MathJax after each update of the document (MathJax
 *   typesets the page itself when it is loaded for the first time).
 * A MutationObserver per viewer notices the updates.
 * Independent of Bootstrap.
 */
(function($)
{
    'use strict';

    // Offset from the top of the scrolling area at which a section counts
    // as being read (px)
    var READ_OFFSET = 80;

    function viewerOf(el)
    {
        return el && el.closest ? el.closest('.pubflow-viewer') : null;
    }

    function isScrolling(el)
    {
        if (!el) {
            return false;
        }
        var overflow = window.getComputedStyle(el).overflowY;
        return (overflow === 'auto' || overflow === 'scroll') &&
            el.scrollHeight > el.clientHeight;
    }

    /**
     * The scrolling area of a viewer: its content or the viewer itself if
     * they scroll (fixed height), else null (the window scrolls).
     */
    function scrollRoot(viewer)
    {
        var content = viewer.querySelector('.pubflow-viewer-content');
        if (isScrolling(content)) {
            return content;
        }
        return isScrolling(viewer) ? viewer : null;
    }

    function atBottom(root)
    {
        if (root) {
            return root.scrollTop > 0 &&
                root.scrollTop + root.clientHeight >= root.scrollHeight - 2;
        }
        var page = document.documentElement;
        return window.pageYOffset > 0 &&
            window.innerHeight + window.pageYOffset >= page.scrollHeight - 2;
    }

    /**
     * The section being read, among those listed in the table of contents
     * (`links`; sections are nested, deeper ones are not listed): the last
     * one whose top has passed the reading line; at the bottom of the
     * scrolling area (where the last sections can't reach that line) the
     * last visible one.
     */
    function currentSection(viewer, links)
    {
        var root = scrollRoot(viewer);
        var rect = root ? root.getBoundingClientRect() :
            { top: 0, bottom: window.innerHeight };
        var line = atBottom(root) ? rect.bottom - 1 : rect.top + READ_OFFSET;
        var current = null;
        for (var i = 0; i < links.length; i++) {
            var section = document.getElementById(
                links[i].getAttribute('href').slice(1)
            );
            if (!section) {
                continue;
            }
            if (!current || section.getBoundingClientRect().top <= line) {
                current = section;
            }
        }
        return current;
    }

    function updateToc(viewer)
    {
        var links = viewer.querySelectorAll('.pubflow-viewer-toc a[href^="#"]');
        if (links.length === 0) {
            return;
        }
        var section = currentSection(viewer, links);
        var target = section ? '#' + section.id : null;
        for (var i = 0; i < links.length; i++) {
            var active = links[i].getAttribute('href') === target;
            links[i].classList.toggle('pubflow-active', active);
            if (active) {
                links[i].setAttribute('aria-current', 'location');
            } else {
                links[i].removeAttribute('aria-current');
            }
        }
    }

    /**
     * Typeset the math of a viewer's document element (once per element:
     * Shiny replaces it on every update). MathJax keeps the math it has
     * typeset, so that of the replaced element is cleared first. Once
     * MathJax has typeset a document, the viewer gets the class
     * pubflow-viewer-mathjax: from then on the math of a new document
     * stays hidden until it is typeset (no flash of raw TeX on updates;
     * see pubflow-viewer.css).
     */
    function typesetMath(viewer, doc)
    {
        var old = viewer.pubflowDoc;
        if (old === doc) {
            return;
        }
        viewer.pubflowDoc = doc;
        var mj = window.MathJax;
        if (!mj || typeof mj.typesetPromise !== 'function') {
            return;     // not loaded (yet): MathJax typesets on startup
        }
        if (old && typeof mj.typesetClear === 'function') {
            mj.typesetClear([old]);
        }
        if (!doc) {
            return;
        }
        var done = function() {
            doc.classList.add('pubflow-typeset');
            viewer.classList.add('pubflow-viewer-mathjax');
        };
        mj.typesetPromise([doc]).then(done, function(err) {
            done();     // show the raw TeX rather than nothing
            if (window.console) {
                window.console.warn('pubflow viewer: MathJax failed', err);
            }
        });
    }

    function refresh(viewer)
    {
        typesetMath(
            viewer,
            viewer.querySelector('.pubflow-viewer-content .pubflow-doc')
        );
        updateToc(viewer);
    }

    /**
     * Refresh a viewer whenever its content changes. Shiny inserts the
     * rendered HTML asynchronously (after its dependencies are loaded), so
     * the viewer is watched instead of Shiny's events; changes made by
     * MathJax only update the table of contents.
     */
    function watch(viewer)
    {
        if (viewer.pubflowWatched) {
            return;
        }
        viewer.pubflowWatched = true;
        var timer = null;
        new MutationObserver(function() {
            window.clearTimeout(timer);
            timer = window.setTimeout(function() { refresh(viewer); }, 50);
        }).observe(viewer, { childList: true, subtree: true });
        refresh(viewer);
    }

    function watchAll()
    {
        var viewers = document.querySelectorAll('.pubflow-viewer');
        for (var i = 0; i < viewers.length; i++) {
            watch(viewers[i]);
        }
    }

    // Update the table of contents of every viewer on scrolling, at most
    // once per animation frame
    var pending = false;
    function onScroll()
    {
        if (pending) {
            return;
        }
        pending = true;
        window.requestAnimationFrame(function() {
            pending = false;
            var viewers = document.querySelectorAll('.pubflow-viewer');
            for (var i = 0; i < viewers.length; i++) {
                updateToc(viewers[i]);
            }
        });
    }
    // capture: scroll events of the viewer's own areas don't bubble
    document.addEventListener('scroll', onScroll,
                              { capture: true, passive: true });
    window.addEventListener('resize', onScroll, { passive: true });

    // Viewers of the page, and viewers inserted later (e.g. by renderUI())
    // when their outputs get values
    $(watchAll);
    $(document).on('shiny:value', function(event) {
        var viewer = viewerOf(event.target);
        if (viewer) {
            watch(viewer);
        }
    });
})(jQuery);
