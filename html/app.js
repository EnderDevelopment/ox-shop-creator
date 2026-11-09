const app = document.querySelector('#app');
const form = document.querySelector('#shopForm');
const list = document.querySelector('#shopList');
const status = document.querySelector('#status');
const statsOutput = document.querySelector('#statsOutput');
let shops = {};

async function post(path, body = {}) {
    const response = await fetch(`https://${GetParentResourceName()}/${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
    });
    return response.json().catch(() => ({}));
}

function showStatus(message, error = false) {
    status.textContent = message;
    status.className = error ? 'status error' : 'status success';
    window.setTimeout(() => { status.textContent = ''; status.className = 'status'; }, 3500);
}

function emptyForm() {
    form.reset();
    form.elements.id.value = '';
    form.elements.name.value = 'New shop';
    form.elements.x.value = 0;
    form.elements.y.value = 0;
    form.elements.z.value = 0;
    form.elements.heading.value = 0;
    form.elements.npcModel.value = 's_m_m_linecook';
    form.elements.blipSprite.value = 52;
    form.elements.blipColour.value = 2;
    form.elements.blipScale.value = 0.75;
    form.elements.open.value = 0;
    form.elements.close.value = 24;
    form.elements.items.value = 'water | 10 | general | 99';
    form.elements.categories.value = 'general=General';
    statsOutput.classList.add('hidden');
    document.querySelectorAll('.shop.active').forEach((node) => node.classList.remove('active'));
}

function fillForm(shop) {
    emptyForm();
    form.elements.id.value = shop.id || '';
    form.elements.name.value = shop.name || '';
    form.elements.x.value = shop.coords?.x ?? 0;
    form.elements.y.value = shop.coords?.y ?? 0;
    form.elements.z.value = shop.coords?.z ?? 0;
    form.elements.heading.value = shop.heading ?? 0;
    form.elements.npc.checked = shop.npc === true;
    form.elements.npcModel.value = shop.npcModel || 's_m_m_linecook';
    form.elements.blip.checked = shop.blip !== false;
    form.elements.blipSprite.value = shop.blipSprite ?? 52;
    form.elements.blipColour.value = shop.blipColour ?? 2;
    form.elements.blipScale.value = shop.blipScale ?? 0.75;
    form.elements.hoursEnabled.checked = shop.hours?.enabled === true;
    form.elements.open.value = shop.hours?.open ?? 0;
    form.elements.close.value = shop.hours?.close ?? 24;
    form.elements.jobs.value = Object.entries(shop.jobs || {}).map(([name, grade]) => `${name}=${grade}`).join('\n');
    form.elements.categories.value = (shop.categories || []).map((category) => `${category.name}=${category.label}`).join(', ');
    form.elements.items.value = (shop.items || []).map((item) => [item.name, item.price, item.category, item.count].join(' | ')).join('\n');
    renderList(shop.id);
}

function renderList(activeId = '') {
    list.innerHTML = '';
    const entries = Object.values(shops);
    if (!entries.length) {
        list.innerHTML = '<p class="muted">No shops saved yet.</p>';
        return;
    }
    entries.sort((a, b) => a.name.localeCompare(b.name)).forEach((shop) => {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = `shop ${shop.id === activeId ? 'active' : ''}`;
        button.innerHTML = `<strong></strong><small></small>`;
        button.querySelector('strong').textContent = shop.name;
        button.querySelector('small').textContent = `${shop.items?.length || 0} items · ${shop.id}`;
        button.onclick = () => fillForm(shop);
        list.appendChild(button);
    });
}

function parseLines() {
    const fields = new FormData(form);
    const items = fields.get('items').split('\n').map((line) => line.split('|').map((part) => part.trim())).filter((parts) => parts[0]).map((parts) => ({
        name: parts[0], price: Number(parts[1]) || 1, category: parts[2] || 'general', count: Number(parts[3]) || 99
    }));
    const categories = fields.get('categories').split(',').map((part) => part.trim()).filter(Boolean).map((part) => {
        const [name, label] = part.split('=').map((value) => value.trim());
        return { name, label: label || name };
    });
    const jobs = {};
    fields.get('jobs').split('\n').map((line) => line.trim()).filter(Boolean).forEach((line) => {
        const [name, grade] = line.split('=').map((value) => value.trim());
        if (name) jobs[name] = Number(grade) || 0;
    });
    return {
        id: fields.get('id') || undefined,
        name: fields.get('name'),
        coords: { x: Number(fields.get('x')), y: Number(fields.get('y')), z: Number(fields.get('z')) },
        heading: Number(fields.get('heading')) || 0,
        npc: fields.get('npc') === 'on', npcModel: fields.get('npcModel'),
        blip: fields.get('blip') === 'on', blipSprite: Number(fields.get('blipSprite')),
        blipColour: Number(fields.get('blipColour')), blipScale: Number(fields.get('blipScale')),
        hours: { enabled: fields.get('hoursEnabled') === 'on', open: Number(fields.get('open')), close: Number(fields.get('close')) },
        jobs, categories, items
    };
}

window.addEventListener('message', async (event) => {
    if (event.data.action === 'shops') { shops = event.data.shops || {}; renderList(form.elements.id.value); }
    if (event.data.action === 'open') {
        app.classList.remove('hidden');
        if (!form.elements.id.value) emptyForm();
        const position = await post('position');
        if (!form.elements.id.value) {
            form.elements.x.value = position.x;
            form.elements.y.value = position.y;
            form.elements.z.value = position.z;
            form.elements.heading.value = position.heading;
        }
        renderList(form.elements.id.value);
    }
    if (event.data.action === 'close') app.classList.add('hidden');
});

document.querySelector('#close').onclick = () => { app.classList.add('hidden'); post('close'); };
document.querySelector('#newShop').onclick = emptyForm;
document.querySelector('#position').onclick = async () => {
    const position = await post('position');
    ['x', 'y', 'z', 'heading'].forEach((key) => { form.elements[key].value = position[key]; });
};
form.onsubmit = async (event) => {
    event.preventDefault();
    const data = parseLines();
    if (!data.name || data.items.length === 0) return showStatus('Enter a name and at least one item.', true);
    await post('save', data);
    showStatus('Shop saved.');
};
document.querySelector('#delete').onclick = async () => {
    const id = form.elements.id.value;
    if (!id) return showStatus('Select a saved shop first.', true);
    await post('delete', { id });
    emptyForm();
    showStatus('Shop deleted.');
};
document.querySelector('#stats').onclick = async () => {
    const result = await post('stats', { id: form.elements.id.value || undefined });
    statsOutput.textContent = JSON.stringify(result, null, 2);
    statsOutput.classList.remove('hidden');
};
