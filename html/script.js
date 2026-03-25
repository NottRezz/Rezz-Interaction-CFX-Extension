(() => {
    const overlay = document.getElementById('interaction-overlay');
    const markers = {};  // targetId -> DOM element
    let expandedId = null;

    // ── Escape HTML to prevent XSS ──
    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    // ── Create a floating marker for a target ──
    function createMarker(target) {
        const marker = document.createElement('div');
        marker.classList.add('target-marker');
        marker.dataset.targetId = target.id;

        // The clickable dot
        const dot = document.createElement('div');
        dot.classList.add('target-dot');
        const firstIcon = (target.options && target.options[0] && target.options[0].icon) || 'fas fa-hand-pointer';
        dot.innerHTML = `<i class="${escapeHtml(firstIcon)}"></i>`;

        dot.addEventListener('click', (e) => {
            e.stopPropagation();
            toggleExpand(target.id);
        });

        marker.appendChild(dot);

        // Options dropdown
        const optionsDiv = document.createElement('div');
        optionsDiv.classList.add('target-options');

        if (target.options) {
            target.options.forEach((opt) => {
                const option = document.createElement('div');
                option.classList.add('interaction-option');

                const iconClass = opt.icon || 'fas fa-hand-pointer';
                const label = opt.label || 'Interact';
                const description = opt.description || '';

                let html = `
                    <div class="option-icon">
                        <i class="${escapeHtml(iconClass)}"></i>
                    </div>
                    <div class="option-text">
                        <span class="option-label">${escapeHtml(label)}</span>
                        ${description ? `<span class="option-description">${escapeHtml(description)}</span>` : ''}
                    </div>
                `;

                option.innerHTML = html;

                option.addEventListener('click', (e) => {
                    e.stopPropagation();
                    selectOption(target.id, opt);
                });

                optionsDiv.appendChild(option);
            });
        }

        marker.appendChild(optionsDiv);
        overlay.appendChild(marker);

        // Fade in
        requestAnimationFrame(() => {
            requestAnimationFrame(() => {
                marker.classList.add('visible');
            });
        });

        return marker;
    }

    // ── Toggle expanded state on a marker ──
    function toggleExpand(targetId) {
        if (expandedId === targetId) {
            // Collapse
            const marker = markers[targetId];
            if (marker) marker.classList.remove('expanded');
            expandedId = null;
        } else {
            // Collapse previous
            if (expandedId && markers[expandedId]) {
                markers[expandedId].classList.remove('expanded');
            }
            // Expand this one
            const marker = markers[targetId];
            if (marker) marker.classList.add('expanded');
            expandedId = targetId;
        }
    }

    // ── Select an option ──
    function selectOption(targetId, opt) {
        fetch(`https://${GetParentResourceName()}/optionSelected`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                targetId: targetId,
                event: opt.event,
                data: opt.data || {},
                index: opt.index,
            })
        });
    }

    // ── Update all markers from Lua scan data ──
    function updateTargets(targets) {
        const activeIds = new Set();

        targets.forEach((target) => {
            activeIds.add(target.id);

            let marker = markers[target.id];

            if (!marker) {
                marker = createMarker(target);
                markers[target.id] = marker;
            }

            // Update position (CSS transition handles smoothing)
            marker.style.left = `${target.screenX * 100}%`;
            marker.style.top = `${target.screenY * 100}%`;

            const scale = Math.max(0.6, Math.min(1.0, 1.0 - (target.dist / 10)));
            marker.querySelector('.target-dot').style.transform = `scale(${scale})`;
        });

        // Remove markers no longer in scan
        for (const id of Object.keys(markers)) {
            if (!activeIds.has(id)) {
                const marker = markers[id];
                marker.classList.remove('visible');
                if (expandedId === id) expandedId = null;
                setTimeout(() => marker.remove(), 200);
                delete markers[id];
            }
        }
    }

    // ── Show overlay ──
    function show() {
        overlay.classList.remove('hidden');
    }

    // ── Hide everything ──
    function hide() {
        expandedId = null;

        // Fade out all markers
        for (const id of Object.keys(markers)) {
            markers[id].classList.remove('visible', 'expanded');
        }

        setTimeout(() => {
            overlay.innerHTML = '';
            for (const id of Object.keys(markers)) {
                delete markers[id];
            }
            overlay.classList.add('hidden');
        }, 200);
    }

    // ── NUI message handler ──
    window.addEventListener('message', (e) => {
        const msg = e.data;

        switch (msg.action) {
            case 'show':
                show();
                break;

            case 'updateTargets':
                updateTargets(msg.targets || []);
                break;

            case 'hide':
                hide();
                break;
        }
    });

    // ── Close on Escape key ──
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            // If a marker is expanded, just collapse it
            if (expandedId) {
                if (markers[expandedId]) {
                    markers[expandedId].classList.remove('expanded');
                }
                expandedId = null;
                return;
            }

            fetch(`https://${GetParentResourceName()}/close`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
        }
    });

    // ── Click on empty space collapses expanded marker ──
    overlay.addEventListener('click', () => {
        if (expandedId && markers[expandedId]) {
            markers[expandedId].classList.remove('expanded');
            expandedId = null;
        }
    });
})();