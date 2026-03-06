/* ============================================================
   ReaderPro Documentation — Script
   SPA navigation, Markdown rendering, search, themes
   ============================================================ */

// ── Configuration ──────────────────────────────────────────

const DOCS_BASE = '..';
const DEFAULT_DOC = 'README.md';
const STORAGE_KEY_DOC = 'readerpro-docs-last';
const STORAGE_KEY_THEME = 'readerpro-docs-theme';

// ── Navigation Manifest ────────────────────────────────────

const NAV_STRUCTURE = [
    { title: 'Home', icon: '\u{1F3E0}', path: 'README.md' },
    { title: 'Getting Started', icon: '\u{1F680}', path: 'GETTING_STARTED.md' },
    {
        title: 'Architecture', icon: '\u{1F3D7}\u{FE0F}', children: [
            { title: 'Why DDD + Hexagonal', path: 'ARCHITECTURE.md' },
            { title: 'Overview', path: 'architecture/OVERVIEW.md' },
            { title: 'Domain Layer', path: 'architecture/DOMAIN_LAYER.md' },
            { title: 'Application Layer', path: 'architecture/APPLICATION_LAYER.md' },
            { title: 'Infrastructure Layer', path: 'architecture/INFRASTRUCTURE_LAYER.md' },
            { title: 'UI Layer', path: 'architecture/UI_LAYER.md' },
        ]
    },
    {
        title: 'Features', icon: '\u{26A1}', children: [
            { title: 'TTS: Kokoro', path: 'features/TTS_KOKORO.md' },
            { title: 'TTS: Qwen3', path: 'features/TTS_QWEN3.md' },
            { title: 'OCR & Documents', path: 'features/OCR.md' },
            { title: 'Project Management', path: 'features/PROJECT_MANAGEMENT.md' },
            { title: 'Audio Playback', path: 'features/AUDIO_PLAYBACK.md' },
            { title: 'Voice Customization', path: 'features/VOICE_CUSTOMIZATION.md' },
        ]
    },
    {
        title: 'Diagrams', icon: '\u{1F4D0}', children: [
            { title: 'Data Flow', path: 'diagrams/data_flow.mermaid' },
            { title: 'Project Structure', path: 'diagrams/project_structure.mermaid' },
            { title: 'Class Diagram', path: 'diagrams/class_diagram.mermaid' },
        ]
    },
    {
        title: 'Development', icon: '\u{1F527}', children: [
            { title: 'Setup', path: 'development/SETUP.md' },
            { title: 'Testing', path: 'development/TESTING.md' },
            { title: 'Adding Features', path: 'development/ADDING_FEATURES.md' },
            { title: 'Coding Standards', path: 'development/CODING_STANDARDS.md' },
        ]
    },
    {
        title: 'Reference', icon: '\u{1F4DA}', children: [
            { title: 'User Guide', path: 'USER_GUIDE.md' },
            { title: 'API Reference', path: 'API_REFERENCE.md' },
            { title: 'Troubleshooting', path: 'TROUBLESHOOTING.md' },
        ]
    },
];

// ── State ──────────────────────────────────────────────────

let currentDoc = null;
let allNavItems = [];
let tocObserver = null;

// ── DOM References ─────────────────────────────────────────

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

const dom = {
    sidebar: () => $('#sidebar'),
    navTree: () => $('#nav-tree'),
    content: () => $('#markdown-content'),
    breadcrumbs: () => $('#breadcrumbs'),
    tocList: () => $('#toc-list'),
    toc: () => $('#toc'),
    search: () => $('#search'),
    loading: () => $('#loading'),
    overlay: () => $('#sidebar-overlay'),
    menuToggle: () => $('#menu-toggle'),
};

// ── Initialize ─────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', init);

function init() {
    initTheme();
    initMarked();
    initMermaid();
    buildNavTree();
    setupSearch();
    setupKeyboard();
    setupMobileMenu();
    setupHashNavigation();

    // Load initial document
    const hash = window.location.hash.slice(1);
    const saved = localStorage.getItem(STORAGE_KEY_DOC);
    const initialDoc = hash || saved || DEFAULT_DOC;
    navigateTo(initialDoc);
}

// ── Theme ──────────────────────────────────────────────────

function initTheme() {
    const saved = localStorage.getItem(STORAGE_KEY_THEME);
    const theme = saved || 'dark';
    applyTheme(theme);

    $('#theme-toggle').addEventListener('click', toggleTheme);
    const mobileToggle = $('#theme-toggle-mobile');
    if (mobileToggle) mobileToggle.addEventListener('click', toggleTheme);
}

function toggleTheme() {
    const current = document.documentElement.getAttribute('data-theme');
    const next = current === 'dark' ? 'light' : 'dark';
    applyTheme(next);
    localStorage.setItem(STORAGE_KEY_THEME, next);
}

function applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    const icon = theme === 'dark' ? '\u{1F319}' : '\u{2600}\u{FE0F}';
    const toggleBtn = $('#theme-toggle');
    const mobileBtn = $('#theme-toggle-mobile');
    if (toggleBtn) toggleBtn.textContent = icon;
    if (mobileBtn) mobileBtn.textContent = icon;

    // Switch highlight.js theme
    const darkLink = $('#hljs-theme-dark');
    const lightLink = $('#hljs-theme-light');
    if (darkLink && lightLink) {
        darkLink.disabled = theme !== 'dark';
        lightLink.disabled = theme !== 'light';
    }
}

// ── Marked.js Configuration ────────────────────────────────

// ── Marked.js Configuration (CORREGIDA) ────────────────────

function initMarked() {
    const renderer = {
        code({ text, lang }) {
            const codeText = text || '';
            if (lang === 'mermaid') {
                const id = 'mmd-' + Math.random().toString(36).substring(2, 11);
                return '<div class="mermaid" id="' + id + '">' + codeText + '</div>';
            }
            let highlighted;
            if (lang && typeof hljs !== 'undefined' && hljs.getLanguage(lang)) {
                highlighted = hljs.highlight(codeText, { language: lang }).value;
            } else if (typeof hljs !== 'undefined') {
                highlighted = hljs.highlightAuto(codeText).value;
            } else {
                highlighted = codeText;
            }
            const langClass = lang ? ' language-' + lang : '';
            return '<pre><code class="hljs' + langClass + '">' + highlighted + '</code></pre>';
        },

        // ⚠️ AQUÍ ESTABA EL ERROR ⚠️
        // Marked pasa los argumentos como (text, level), NO como un objeto {tokens}
        heading(text, level) {
            const slug = text
                .toLowerCase()
                .replace(/<[^>]*>/g, '') // Quitar HTML si hubiera
                .replace(/[^\w\s-]/g, '')
                .replace(/\s+/g, '-')
                .replace(/-+/g, '-')
                .trim();

            return `<h${level} id="${slug}">${text}</h${level}>\n`;
        }
    };

    marked.use({
        renderer,
        gfm: true,
        breaks: false
    });
}

// ── Mermaid Configuration ──────────────────────────────────

function initMermaid() {
    const theme = document.documentElement.getAttribute('data-theme');
    mermaid.initialize({
        startOnLoad: false,
        theme: theme === 'dark' ? 'dark' : 'default',
        securityLevel: 'loose',
        fontFamily: '-apple-system, BlinkMacSystemFont, sans-serif',
    });
}

// ── Navigation Tree ────────────────────────────────────────

function buildNavTree() {
    const navEl = dom.navTree();
    navEl.innerHTML = '';
    allNavItems = [];

    for (const item of NAV_STRUCTURE) {
        if (item.children) {
            navEl.appendChild(createNavSection(item));
        } else {
            navEl.appendChild(createTopLevelItem(item));
        }
    }
}

function createTopLevelItem(item) {
    const a = document.createElement('a');
    a.className = 'nav-item top-level';
    a.innerHTML = '<span class="icon">' + item.icon + '</span>' + item.title;
    a.dataset.path = item.path;
    a.addEventListener('click', (e) => {
        e.preventDefault();
        navigateTo(item.path);
        closeMobileMenu();
    });
    allNavItems.push({ el: a, path: item.path, title: item.title });
    return a;
}

function createNavSection(section) {
    const div = document.createElement('div');
    div.className = 'nav-section';

    const header = document.createElement('button');
    header.className = 'nav-section-header';
    header.innerHTML =
        '<span class="icon">' + section.icon + '</span>' +
        '<span>' + section.title + '</span>' +
        '<span class="chevron">\u{25B6}</span>';
    header.addEventListener('click', () => {
        div.classList.toggle('open');
    });

    const children = document.createElement('div');
    children.className = 'nav-children';

    for (const child of section.children) {
        const a = document.createElement('a');
        a.className = 'nav-item';
        a.textContent = child.title;
        a.dataset.path = child.path;
        a.addEventListener('click', (e) => {
            e.preventDefault();
            navigateTo(child.path);
            closeMobileMenu();
        });
        children.appendChild(a);
        allNavItems.push({
            el: a,
            path: child.path,
            title: child.title,
            section: section.title,
            sectionEl: div
        });
    }

    div.appendChild(header);
    div.appendChild(children);
    return div;
}

// ── Navigation ─────────────────────────────────────────────

async function navigateTo(path) {
    if (!path) return;

    // Show loading
    dom.loading().classList.remove('hidden');

    try {
        const content = await fetchDocument(path);
        currentDoc = path;
        window.location.hash = path;
        localStorage.setItem(STORAGE_KEY_DOC, path);

        // Render
        renderContent(content, path);
        updateActiveNav(path);
        updateBreadcrumbs(path);
        buildTOC();
        addCopyButtons();
        handleInternalLinks();

        // Render mermaid diagrams
        await renderMermaidDiagrams();

        // Scroll to top
        dom.content().scrollIntoView({ behavior: 'instant', block: 'start' });
        window.scrollTo(0, 0);

        // Setup TOC scroll observer
        setupTOCObserver();

    } catch (err) {
        dom.content().innerHTML =
            '<div class="welcome">' +
            '<h2>Document Not Found</h2>' +
            '<p>Could not load <code>' + path + '</code></p>' +
            '<p style="font-size: 0.9rem;">' + err.message + '</p>' +
            '</div>';
    }

    dom.loading().classList.add('hidden');
}

async function fetchDocument(path) {
    const url = DOCS_BASE + '/' + path;
    // 👇 AGREGA ESTO
    console.group('🔍 Debug Fetch');
    console.log('Path recibido:', path);
    console.log('Base:', DOCS_BASE);
    console.log('URL final:', url);
    console.groupEnd();
    // 👆
    const response = await fetch(url);
    if (!response.ok) {
        throw new Error('HTTP ' + response.status + ': ' + response.statusText);
    }
    let content = await response.text();

    // Wrap .mermaid files as markdown with a mermaid code block
    if (path.endsWith('.mermaid')) {
        const title = formatTitle(path);
        content = '# ' + title + '\n\n```mermaid\n' + content + '\n```';
    }

    return content;
}

function renderContent(markdown, path) {
    const html = marked.parse(markdown);
    dom.content().innerHTML = html;
}

// ── Breadcrumbs ────────────────────────────────────────────

function updateBreadcrumbs(path) {
    const el = dom.breadcrumbs();
    const parts = path.split('/');
    const fileName = parts.pop();
    const title = formatTitle(path);

    let html = '<a data-path="README.md">Docs</a>';

    if (parts.length > 0) {
        html += '<span class="separator">\u{25B8}</span>';
        html += '<span>' + formatFolderName(parts[0]) + '</span>';
    }

    html += '<span class="separator">\u{25B8}</span>';
    html += '<span class="current">' + title + '</span>';

    el.innerHTML = html;

    // Make breadcrumb links clickable
    el.querySelectorAll('a[data-path]').forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            navigateTo(link.dataset.path);
        });
    });
}

// ── Table of Contents ──────────────────────────────────────

function buildTOC() {
    const tocList = dom.tocList();
    const headings = dom.content().querySelectorAll('h2, h3');

    if (headings.length < 2) {
        dom.toc().style.display = 'none';
        tocList.innerHTML = '';
        return;
    }

    dom.toc().style.display = '';
    let html = '';

    headings.forEach(h => {
        const level = h.tagName.toLowerCase();
        const text = h.textContent;
        const id = h.id;
        const cls = level === 'h3' ? ' class="toc-h3"' : '';
        html += '<li><a href="#' + id + '"' + cls + ' data-id="' + id + '">' + text + '</a></li>';
    });

    tocList.innerHTML = html;

    // Click handler for smooth scroll
    tocList.querySelectorAll('a').forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const target = document.getElementById(link.dataset.id);
            if (target) {
                target.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        });
    });
}

function setupTOCObserver() {
    // Disconnect previous observer
    if (tocObserver) tocObserver.disconnect();

    const headings = dom.content().querySelectorAll('h2, h3');
    if (headings.length < 2) return;

    tocObserver = new IntersectionObserver((entries) => {
        for (const entry of entries) {
            if (entry.isIntersecting) {
                const id = entry.target.id;
                dom.tocList().querySelectorAll('a').forEach(a => {
                    a.classList.toggle('active', a.dataset.id === id);
                });
                break;
            }
        }
    }, { rootMargin: '-80px 0px -60% 0px', threshold: 0 });

    headings.forEach(h => tocObserver.observe(h));
}

// ── Active Nav Highlight ───────────────────────────────────

function updateActiveNav(path) {
    // Remove all active states
    allNavItems.forEach(item => {
        item.el.classList.remove('active');
    });

    // Set active and expand parent section
    const match = allNavItems.find(item => item.path === path);
    if (match) {
        match.el.classList.add('active');
        if (match.sectionEl) {
            match.sectionEl.classList.add('open');
        }
    }
}

// ── Copy Buttons ───────────────────────────────────────────

function addCopyButtons() {
    dom.content().querySelectorAll('pre').forEach(pre => {
        // Skip if already has a copy button
        if (pre.querySelector('.copy-btn')) return;

        const btn = document.createElement('button');
        btn.className = 'copy-btn';
        btn.textContent = 'Copy';
        btn.addEventListener('click', async () => {
            const code = pre.querySelector('code');
            if (!code) return;
            try {
                await navigator.clipboard.writeText(code.textContent);
                btn.textContent = 'Copied!';
                btn.classList.add('copied');
                setTimeout(() => {
                    btn.textContent = 'Copy';
                    btn.classList.remove('copied');
                }, 2000);
            } catch {
                btn.textContent = 'Failed';
                setTimeout(() => { btn.textContent = 'Copy'; }, 2000);
            }
        });
        pre.appendChild(btn);
    });
}

// ── Internal Links ─────────────────────────────────────────

function handleInternalLinks() {
    dom.content().querySelectorAll('a').forEach(link => {
        const href = link.getAttribute('href');
        if (!href) return;

        // Internal .md or .mermaid links
        if ((href.endsWith('.md') || href.endsWith('.mermaid')) && !href.startsWith('http')) {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                const resolved = resolveRelativePath(currentDoc, href);
                navigateTo(resolved);
            });
        }

        // Anchor links
        if (href.startsWith('#')) {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                const target = document.getElementById(href.slice(1));
                if (target) {
                    target.scrollIntoView({ behavior: 'smooth', block: 'start' });
                }
            });
        }

        // External links open in new tab
        if (href.startsWith('http')) {
            link.setAttribute('target', '_blank');
            link.setAttribute('rel', 'noopener');
        }
    });
}

function resolveRelativePath(currentPath, relativePath) {
    // Remove any anchor from relative path
    const cleanRelative = relativePath.split('#')[0];

    // Get current directory
    const lastSlash = currentPath.lastIndexOf('/');
    const currentDir = lastSlash >= 0 ? currentPath.substring(0, lastSlash + 1) : '';

    // Combine and resolve
    const combined = currentDir + cleanRelative;
    const parts = combined.split('/');
    const resolved = [];

    for (const part of parts) {
        if (part === '..') {
            resolved.pop();
        } else if (part !== '.' && part !== '') {
            resolved.push(part);
        }
    }

    return resolved.join('/');
}

// ── Mermaid Rendering ──────────────────────────────────────

async function renderMermaidDiagrams() {
    const diagrams = dom.content().querySelectorAll('.mermaid');
    if (diagrams.length === 0) return;

    // Re-init mermaid with current theme
    const theme = document.documentElement.getAttribute('data-theme');
    mermaid.initialize({
        startOnLoad: false,
        theme: theme === 'dark' ? 'dark' : 'default',
        securityLevel: 'loose',
        fontFamily: '-apple-system, BlinkMacSystemFont, sans-serif',
    });

    try {
        await mermaid.run({ nodes: diagrams });
    } catch (err) {
        console.warn('Mermaid rendering error:', err);
    }
}

// ── Search ─────────────────────────────────────────────────

function setupSearch() {
    const searchInput = dom.search();
    let debounceTimer;

    searchInput.addEventListener('input', () => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
            performSearch(searchInput.value.trim());
        }, 150);
    });

    searchInput.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            searchInput.value = '';
            performSearch('');
            searchInput.blur();
        }
    });
}

function performSearch(query) {
    const navSections = dom.navTree().querySelectorAll('.nav-section');
    const topItems = dom.navTree().querySelectorAll('.nav-item.top-level');
    const shortcut = document.querySelector('.search-shortcut');

    if (!query) {
        // Reset all visibility
        navSections.forEach(s => s.classList.remove('search-hidden'));
        topItems.forEach(i => {
            i.classList.remove('search-hidden', 'search-match');
        });
        allNavItems.forEach(item => {
            item.el.classList.remove('search-hidden', 'search-match');
        });
        if (shortcut) shortcut.style.display = '';
        return;
    }

    if (shortcut) shortcut.style.display = 'none';
    const lowerQuery = query.toLowerCase();

    // Filter nav items
    allNavItems.forEach(item => {
        const matches = item.title.toLowerCase().includes(lowerQuery) ||
            (item.section && item.section.toLowerCase().includes(lowerQuery)) ||
            item.path.toLowerCase().includes(lowerQuery);

        item.el.classList.toggle('search-hidden', !matches);
        item.el.classList.toggle('search-match', matches);
    });

    // Show/hide sections based on whether they have visible children
    navSections.forEach(section => {
        const visibleChildren = section.querySelectorAll('.nav-item:not(.search-hidden)');
        section.classList.toggle('search-hidden', visibleChildren.length === 0);
        if (visibleChildren.length > 0) {
            section.classList.add('open');
        }
    });

    // Handle top-level items
    topItems.forEach(item => {
        const path = item.dataset.path || '';
        const text = item.textContent.toLowerCase();
        const matches = text.includes(lowerQuery) || path.toLowerCase().includes(lowerQuery);
        item.classList.toggle('search-hidden', !matches);
        item.classList.toggle('search-match', matches);
    });
}

// ── Keyboard Shortcuts ─────────────────────────────────────

function setupKeyboard() {
    document.addEventListener('keydown', (e) => {
        // "/" to focus search
        if (e.key === '/' && !isInputFocused()) {
            e.preventDefault();
            dom.search().focus();
        }

        // Escape to close mobile menu
        if (e.key === 'Escape') {
            closeMobileMenu();
        }
    });
}

function isInputFocused() {
    const active = document.activeElement;
    return active && (active.tagName === 'INPUT' || active.tagName === 'TEXTAREA');
}

// ── Mobile Menu ────────────────────────────────────────────

function setupMobileMenu() {
    const toggle = dom.menuToggle();
    const overlay = dom.overlay();

    if (toggle) {
        toggle.addEventListener('click', () => {
            const sidebar = dom.sidebar();
            sidebar.classList.toggle('open');
            overlay.classList.toggle('visible');
        });
    }

    if (overlay) {
        overlay.addEventListener('click', closeMobileMenu);
    }
}

function closeMobileMenu() {
    dom.sidebar().classList.remove('open');
    dom.overlay().classList.remove('visible');
}

// ── Hash Navigation ────────────────────────────────────────

function setupHashNavigation() {
    window.addEventListener('hashchange', () => {
        const path = window.location.hash.slice(1);
        if (path && path !== currentDoc) {
            navigateTo(path);
        }
    });
}

// ── Utility Functions ──────────────────────────────────────

function formatTitle(path) {
    // Look up in nav manifest first
    for (const item of NAV_STRUCTURE) {
        if (item.path === path) return item.title;
        if (item.children) {
            const child = item.children.find(c => c.path === path);
            if (child) return child.title;
        }
    }

    // Fallback: format filename
    const file = path.split('/').pop().replace(/\.(md|mermaid)$/, '');
    return file
        .replace(/[_-]/g, ' ')
        .replace(/\b\w/g, c => c.toUpperCase());
}

function formatFolderName(folder) {
    const map = {
        'architecture': 'Architecture',
        'features': 'Features',
        'diagrams': 'Diagrams',
        'development': 'Development',
    };
    return map[folder] || folder.charAt(0).toUpperCase() + folder.slice(1);
}
