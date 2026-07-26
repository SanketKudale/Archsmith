/// Browser assets embedded in the Archsmith executable.
abstract final class StudioAssets {
  static const html = r'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Archsmith Studio</title>
  <link rel="stylesheet" href="/styles.css">
</head>
<body>
  <header>
    <div class="brand"><span>AS</span><strong>Archsmith Studio</strong></div>
    <select id="screens" aria-label="Saved screens"><option value="">New screen</option></select>
    <input id="screenName" value="home" aria-label="Screen name">
    <input id="featureName" value="home" aria-label="Feature">
    <input id="route" value="/home" aria-label="Route">
    <div id="breakpoints" class="breakpoints"></div>
    <button id="undo" class="icon secondary" title="Undo">↶</button>
    <button id="redo" class="icon secondary" title="Redo">↷</button>
    <button id="save" class="secondary">Save</button>
    <button id="generate">Generate Dart</button>
  </header>
  <main>
    <aside class="palette panel">
      <h2>Screens</h2>
      <div class="screen-actions">
        <button id="newScreen" class="secondary">New</button>
        <button id="duplicateScreen" class="secondary">Copy</button>
        <button id="deleteScreen" class="danger">Delete</button>
      </div>
      <label>Template<select id="templates"><option value="">Choose template</option></select></label>
      <div class="screen-actions">
        <button id="applyTemplate" class="secondary">Apply</button>
        <button id="saveTemplate" class="secondary">Save current</button>
      </div>
      <hr>
      <h2>Components</h2>
      <input id="componentSearch" type="search" placeholder="Search components">
      <div id="components"></div>
      <hr>
      <h2>Component tree</h2>
      <div id="componentTree"></div>
    </aside>
    <section class="workspace">
      <div id="status">Ready</div>
      <div id="device" style="width:390px">
        <div id="canvas" class="dropzone"></div>
      </div>
    </section>
    <aside class="inspector panel">
      <h2>Inspector</h2>
      <div id="emptyInspector">Select a component on the canvas.</div>
      <div id="inspector" hidden>
        <label>Node ID<input id="nodeId"></label>
        <label class="override"><input id="breakpointOverride" type="checkbox"> Edit only the active breakpoint</label>
        <div id="properties"></div>
        <hr>
        <label>API action
          <input id="actionSearch" type="search" placeholder="Search provider/controller">
          <select id="actionSelect"><option value="">No action</option></select>
        </label>
        <div id="arguments"></div>
        <label>Success route<input id="successRoute" placeholder="/next"></label>
        <label>Error route<input id="errorRoute" placeholder="/try-again"></label>
        <label>Success feedback<input id="successMessage" placeholder="Saved successfully"></label>
        <label>Error feedback<input id="errorMessage" placeholder="Could not save"></label>
        <hr>
        <h2>Action flow</h2>
        <div id="flowSteps"></div>
        <button id="addFlowStep" class="secondary wide">Add API step</button>
        <button id="duplicate" class="secondary wide">Duplicate component</button>
        <button id="remove" class="danger">Remove component</button>
      </div>
      <hr>
      <h2>Responsive ranges</h2>
      <div id="breakpointEditor"></div>
    </aside>
  </main>
  <script src="/app.js"></script>
</body>
</html>''';

  static const css = r'''
:root{font-family:Inter,system-ui,sans-serif;color:#e9eef9;background:#0a0d14}
*{box-sizing:border-box}body{margin:0;overflow:hidden}button,input,select,textarea{font:inherit}
header{height:64px;display:flex;align-items:center;gap:10px;padding:10px 16px;border-bottom:1px solid #252b39;background:#101520}
.brand{display:flex;align-items:center;gap:9px;margin-right:10px;white-space:nowrap}.brand span{display:grid;place-items:center;width:34px;height:34px;border-radius:10px;background:linear-gradient(135deg,#7557ff,#31c5f4);font-weight:800}
input,select,textarea{width:100%;color:#e9eef9;background:#151b28;border:1px solid #30384a;border-radius:8px;padding:9px 10px;outline:none}input:focus,select:focus,textarea:focus{border-color:#7557ff}
header input,header select{width:145px}header #route{width:190px}.breakpoints{display:flex;margin-left:auto;background:#171d2a;border-radius:9px;padding:3px}.breakpoints button{background:transparent;color:#8e99ad}.breakpoints button.active{background:#30394d;color:#fff}
button{border:0;border-radius:8px;padding:9px 13px;color:white;background:#7357f5;cursor:pointer}button.secondary{background:#293247}button.danger{width:100%;margin-top:18px;background:#542a36;color:#ffabbc}
button.icon{font-size:18px;padding:6px 11px}button.wide{width:100%;margin-top:18px}
button:disabled{opacity:.35;cursor:not-allowed}
.screen-actions{display:flex;gap:7px;margin:8px 0}.screen-actions button{flex:1;padding:7px}.screen-actions button.danger{width:auto;margin:0}.tree-item{padding:6px 7px;border-radius:6px;color:#aeb8ca;cursor:pointer;font-size:12px}.tree-item:hover,.tree-item.selected{background:#292f47;color:white}.tree-type{color:#7763df}.breakpoint-row{padding:8px;margin:7px 0;border:1px solid #293247;border-radius:8px}.breakpoint-row strong{font-size:12px}.breakpoint-values{display:flex;gap:6px}.breakpoint-values label{flex:1}
main{height:calc(100vh - 64px);display:grid;grid-template-columns:240px minmax(400px,1fr) 300px}.panel{background:#101520;padding:18px;overflow:auto}.palette{border-right:1px solid #252b39}.inspector{border-left:1px solid #252b39}h2{font-size:14px;text-transform:uppercase;letter-spacing:.08em;color:#8d98ad;margin:0 0 14px}
#components{margin-top:13px}.category{font-size:11px;color:#727f96;margin:18px 0 7px;text-transform:uppercase}.component{display:flex;align-items:center;gap:9px;padding:10px;margin:5px 0;border:1px solid #283044;border-radius:9px;background:#161c29;cursor:grab}.component:before{content:"+";display:grid;place-items:center;width:22px;height:22px;border-radius:6px;background:#292f47;color:#a89aff}
.workspace{position:relative;overflow:auto;display:flex;justify-content:center;padding:45px;background-image:radial-gradient(#283042 1px,transparent 1px);background-size:22px 22px}
#status{position:fixed;z-index:3;top:74px;left:50%;transform:translateX(-50%);padding:7px 12px;border-radius:20px;background:#181f2d;color:#98a3b6;font-size:12px}
#device{min-height:720px;transition:width .2s;background:white;border-radius:18px;box-shadow:0 18px 60px #0009;overflow:hidden;color:#1c2330}
#canvas{min-height:720px;padding:14px}.dropzone.dragover{outline:2px dashed #7557ff;outline-offset:-6px}
.node{position:relative;border:1px dashed transparent;border-radius:8px;padding:7px;margin:3px;min-height:34px}.node:hover{border-color:#a89aff}.node.selected{border:2px solid #7557ff}.node-tag{position:absolute;right:4px;top:3px;font-size:9px;color:#765cf0;background:#eeeaff;padding:2px 5px;border-radius:4px}
.preview-text{padding:5px}.preview-field{padding:11px;border:1px solid #b8bfca;border-radius:8px;color:#77808f}.preview-button{padding:10px 18px;text-align:center;color:white;background:#7357f5;border-radius:8px}.preview-card{padding:12px;box-shadow:0 2px 10px #14213d22;border-radius:10px}.preview-row{display:flex;gap:8px}.preview-column{display:flex;flex-direction:column;gap:8px}
label{display:block;font-size:12px;color:#98a3b6;margin:12px 0 5px}label input,label select{margin-top:5px}.property{margin-bottom:10px}hr{border:0;border-top:1px solid #293042;margin:18px 0}.arg-help{font-size:11px;color:#778399;margin-top:3px}
.override{display:flex;align-items:center;gap:8px;padding:8px;border-radius:8px;background:#171d2a}.override input{width:auto;margin:0}
.parameter-group{margin:10px 0;padding:10px;border:1px solid #2c3548;border-radius:9px}.parameter-title{font-size:12px;color:#b6c0d2;margin-bottom:8px}.list-item{position:relative;margin:8px 0;padding:8px;background:#151b27;border-radius:8px}.list-item .remove-item{position:absolute;right:6px;top:6px;width:auto;padding:3px 7px;background:#542a36}.add-item{width:100%;margin-top:7px;background:#293247}
.flow-step{margin:10px 0;padding:10px;border:1px solid #38425a;border-radius:9px;background:#151b27}.flow-step-head{display:flex;gap:7px}.flow-step-head button{padding:5px 9px;background:#542a36}.flow-step label{margin-top:8px}
''';

  static const js = r'''
let bootstrap, schema, selected = null, draggedType = null, draggedNodeId = null;
let history = [], future = [];
const $ = id => document.getElementById(id);
const uid = type => `${type}_${Math.random().toString(36).slice(2,8)}`;

async function request(url, options) {
  const response = await fetch(url, options);
  const body = await response.json();
  if (!response.ok) throw new Error(body.error || 'Request failed');
  return body;
}

async function init() {
  bootstrap = await request('/api/bootstrap');
  schema = {
    version: 1, name: 'home', feature: 'home', route: '/home',
    breakpoints: bootstrap.breakpoints,
    root: {id:'page',type:'appScaffold',properties:{title:'Home'},children:[]}
  };
  bootstrap.screens.forEach(name=>$('screens').add(new Option(name,name)));
  bootstrap.templates.forEach(name=>$('templates').add(new Option(name,name)));
  renderPalette();
  bindControls();
  renderBreakpoints();
  render();
}

function renderPalette(filter='') {
  const host = $('components'); host.innerHTML = '';
  const groups = {};
  bootstrap.components.filter(c => `${c.label} ${c.category}`.toLowerCase().includes(filter.toLowerCase()))
    .forEach(c => (groups[c.category] ||= []).push(c));
  Object.entries(groups).forEach(([category, items]) => {
    host.insertAdjacentHTML('beforeend', `<div class="category">${category}</div>`);
    items.forEach(c => {
      const element = document.createElement('div');
      element.className='component'; element.draggable=true; element.textContent=c.label;
      element.ondragstart=()=>{draggedType=c.type;draggedNodeId=null};
      element.ondblclick=()=>addNode(c.type);
      host.appendChild(element);
    });
  });
}

function descriptor(type){ return bootstrap.components.find(c=>c.type===type); }
function findNode(node,id,parent=null){
  if(node.id===id)return {node,parent};
  for(const child of node.children||[]){const found=findNode(child,id,node);if(found)return found;}
}
function addNode(type,targetId){
  const component=descriptor(type), node={id:uid(type),type,properties:{...component.defaults},children:[]};
  const target=targetId ? findNode(schema.root,targetId)?.node : (selected||schema.root);
  const destination=descriptor(target.type)?.accepts_children ? target : schema.root;
  checkpoint();
  destination.children ||= []; destination.children.push(node); selected=node; render();
}
function removeSelected(){
  if(!selected||selected===schema.root)return;
  checkpoint();
  const found=findNode(schema.root,selected.id); found.parent.children=found.parent.children.filter(n=>n!==selected);
  selected=null; render();
}
function moveNode(nodeId,targetId){
  if(!nodeId||nodeId===schema.root.id||nodeId===targetId)return;
  const source=findNode(schema.root,nodeId), target=findNode(schema.root,targetId);
  if(!source?.parent||!target)return;
  const destination=descriptor(target.node.type)?.accepts_children?target.node:target.parent;
  if(!destination||findNode(source.node,destination.id))return setStatus('A component cannot contain itself.',true);
  checkpoint();
  source.parent.children=source.parent.children.filter(node=>node!==source.node);
  destination.children||=[];destination.children.push(source.node);
  selected=source.node;render();
}
function duplicateSelected(){
  if(!selected||selected===schema.root)return;
  const found=findNode(schema.root,selected.id);checkpoint();
  const copy=JSON.parse(JSON.stringify(selected));
  const renew=node=>{node.id=uid(node.type);(node.children||[]).forEach(renew)};renew(copy);
  const index=found.parent.children.indexOf(selected);found.parent.children.splice(index+1,0,copy);
  selected=copy;render();
}
function checkpoint(){history.push(JSON.stringify(schema));if(history.length>100)history.shift();future=[];updateHistoryButtons()}
function undo(){
  if(!history.length)return;future.push(JSON.stringify(schema));schema=JSON.parse(history.pop());selected=null;syncScreenFields();renderBreakpoints();render();updateHistoryButtons();
}
function redo(){
  if(!future.length)return;history.push(JSON.stringify(schema));schema=JSON.parse(future.pop());selected=null;syncScreenFields();renderBreakpoints();render();updateHistoryButtons();
}
function updateHistoryButtons(){$('undo').disabled=!history.length;$('redo').disabled=!future.length}
function syncScreenFields(){$('screenName').value=schema.name;$('featureName').value=schema.feature||schema.name;$('route').value=schema.route||''}
function freshSchema(name='home'){
  return {version:1,name,feature:name,route:`/${name.replaceAll('_','-')}`,breakpoints:JSON.parse(JSON.stringify(bootstrap.breakpoints)),root:{id:'page',type:'appScaffold',properties:{title:name.replaceAll('_',' ')},children:[]}};
}
function newScreen(){checkpoint();schema=freshSchema('new_screen');selected=null;syncScreenFields();$('screens').value='';renderBreakpoints();render()}
function duplicateScreen(){checkpoint();schema=JSON.parse(JSON.stringify(schema));schema.name=`${schema.name}_copy`;schema.feature=`${schema.feature||schema.name}_copy`;schema.route=`${schema.route||'/screen'}-copy`;selected=null;syncScreenFields();$('screens').value='';renderBreakpoints();render()}
async function deleteScreen(){
  const name=$('screens').value;if(!name)return setStatus('Select a saved screen first.',true);
  if(!confirm(`Delete the ${name} Studio schema? Generated Dart files are kept.`))return;
  try{const result=await request(`/api/screens/${encodeURIComponent(name)}`,{method:'DELETE'});$('screens').querySelector(`option[value="${CSS.escape(name)}"]`)?.remove();newScreen();setStatus(result.message)}catch(error){setStatus(error.message,true)}
}
async function applyTemplate(){
  const name=$('templates').value;if(!name)return setStatus('Choose a template first.',true);
  try{const template=await request(`/api/templates/${encodeURIComponent(name)}`);checkpoint();const identity={name:schema.name,feature:schema.feature,route:schema.route};schema=template;Object.assign(schema,identity);selected=null;syncScreenFields();renderBreakpoints();render();setStatus(`Applied ${name} template`)}catch(error){setStatus(error.message,true)}
}
async function saveTemplate(){
  const name=prompt('Template name',`${schema.name}_template`);if(!name)return;
  const template=JSON.parse(JSON.stringify(schema));template.name=name;
  try{const result=await request('/api/templates',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(template)});if(![...$('templates').options].some(option=>option.value===name))$('templates').add(new Option(name,name));$('templates').value=name;setStatus(result.message)}catch(error){setStatus(error.message,true)}
}

function render(){
  schema.name=$('screenName').value; schema.feature=$('featureName').value; schema.route=$('route').value;
  renderCanvas();
  renderTree();
  renderInspector();
}
function renderCanvas(){
  $('canvas').innerHTML=''; $('canvas').appendChild(renderNode(schema.root));
}
function renderNode(node){
  const element=document.createElement('div'); element.className='node'+(selected===node?' selected':'');
  element.draggable=node!==schema.root;
  element.ondragstart=e=>{e.stopPropagation();draggedNodeId=node.id;draggedType=null};
  element.ondragend=()=>{draggedNodeId=null;draggedType=null};
  element.dataset.id=node.id; element.onclick=e=>{e.stopPropagation();selected=node;render()};
  element.ondragover=e=>{e.preventDefault();element.classList.add('dragover')};
  element.ondragleave=()=>element.classList.remove('dragover');
  element.ondrop=e=>{e.preventDefault();e.stopPropagation();element.classList.remove('dragover');if(draggedType)addNode(draggedType,node.id);else if(draggedNodeId)moveNode(draggedNodeId,node.id)};
  element.insertAdjacentHTML('beforeend',`<span class="node-tag">${node.type}</span>`);
  const props={...node.properties,...(node.responsive?.[currentBreakpoint()]||{})};
  const content=document.createElement('div');
  content.className=node.type==='row'?'preview-row':node.type==='column'||node.type==='appScaffold'?'preview-column':node.type==='card'?'preview-card':'';
  if(node.type==='text')content.innerHTML=`<div class="preview-text">${escapeHtml(props.text||'Text')}</div>`;
  else if(node.type==='appTextField')content.innerHTML=`<div class="preview-field">${escapeHtml(props.label||props.hint||'Text field')}</div>`;
  else if(node.type==='appButton')content.innerHTML=`<div class="preview-button">${escapeHtml(props.label||'Continue')}</div>`;
  else if(node.type==='appLoadingIndicator')content.innerHTML='<div class="preview-text">◌ Loading</div>';
  else if(node.type==='stateList'||node.type==='stateGrid'){
    content.className=node.type==='stateGrid'?'preview-row':'preview-column';
    for(let index=0;index<3;index++)content.insertAdjacentHTML('beforeend',`<div class="preview-card">Response item ${index+1}</div>`);
  }
  else if(node.type==='spacer')content.style.height=`${props.size||16}px`;
  (node.children||[]).forEach(child=>content.appendChild(renderNode(child)));
  element.appendChild(content); return element;
}
function escapeHtml(value){const div=document.createElement('div');div.textContent=value;return div.innerHTML}
function currentBreakpoint(){return document.querySelector('#breakpoints button.active')?.dataset.name||schema.breakpoints[0]?.name||'mobile'}
function breakpointWidth(item){if(item.min_width&&item.max_width)return Math.round((item.min_width+item.max_width)/2);if(item.min_width)return Math.max(item.min_width,1280);return Math.min(item.max_width||390,390)}
function renderBreakpoints(active=currentBreakpoint()){
  const host=$('breakpoints');host.innerHTML='';
  schema.breakpoints.forEach((item,index)=>{
    const button=document.createElement('button');button.textContent=item.name;button.dataset.name=item.name;button.dataset.width=breakpointWidth(item);
    if(item.name===active||(!schema.breakpoints.some(value=>value.name===active)&&index===0))button.classList.add('active');
    button.onclick=()=>{host.querySelectorAll('button').forEach(value=>value.classList.remove('active'));button.classList.add('active');$('device').style.width=`${button.dataset.width}px`;render()};
    host.appendChild(button);
  });
  const selected=host.querySelector('button.active');if(selected)$('device').style.width=`${selected.dataset.width}px`;
  renderBreakpointEditor();
}
function renderBreakpointEditor(){
  const host=$('breakpointEditor');host.innerHTML='';
  schema.breakpoints.forEach(item=>{
    const row=document.createElement('div');row.className='breakpoint-row';row.innerHTML=`<strong>${escapeHtml(item.name)}</strong>`;
    const values=document.createElement('div');values.className='breakpoint-values';
    [['min_width','Min'],['max_width','Max']].forEach(([key,title])=>{const label=document.createElement('label');label.textContent=title;const input=document.createElement('input');input.type='number';input.min='0';input.value=item[key]??'';input.onchange=()=>{checkpoint();item[key]=input.value===''?undefined:Number(input.value);renderBreakpoints(item.name)};label.appendChild(input);values.appendChild(label)});
    row.appendChild(values);host.appendChild(row);
  });
}
function renderTree(){
  const host=$('componentTree');host.innerHTML='';
  const visit=(node,depth)=>{const item=document.createElement('div');item.className='tree-item'+(selected===node?' selected':'');item.style.paddingLeft=`${7+depth*13}px`;item.innerHTML=`<span class="tree-type">${escapeHtml(node.type)}</span> · ${escapeHtml(node.id)}`;item.onclick=()=>{selected=node;render()};host.appendChild(item);(node.children||[]).forEach(child=>visit(child,depth+1))};
  visit(schema.root,0);
}

function renderInspector(){
  $('emptyInspector').hidden=!!selected; $('inspector').hidden=!selected;if(!selected)return;
  $('nodeId').value=selected.id;
  const component=descriptor(selected.type), host=$('properties');host.innerHTML='';
  const override=$('breakpointOverride').checked, breakpoint=currentBreakpoint();
  selected.responsive||={};if(override)selected.responsive[breakpoint]||={};
  const propertySource=override?selected.responsive[breakpoint]:(selected.properties||={});
  component.properties.forEach(property=>{
    const label=document.createElement('label');label.className='property';label.textContent=property.label;
    let input;
    if(property.type==='select'){input=document.createElement('select');property.options.forEach(v=>input.add(new Option(v,v)))}
    else if(property.type==='binding'){
      input=document.createElement('select');input.add(new Option('Choose state value',''));
      const action=bootstrap.actions.find(item=>item.id===selected.action?.action_id);
      const paths=new Set(Object.keys(action?.state||{isLoading:'isLoading',data:'data',error:'error',isEmpty:'isEmpty'}));
      responsePaths(action?.response_fields||[]).forEach(path=>paths.add(path));
      paths.forEach(v=>input.add(new Option(v,v)));
    }
    else if(property.type==='listBinding'){
      input=document.createElement('select');input.add(new Option('Choose response list',''));
      const action=bootstrap.actions.find(item=>item.id===selected.action?.action_id);
      responseListPaths(action?.response_fields||[]).forEach(v=>input.add(new Option(v,v)));
    }
    else if(property.type==='itemBinding'){
      input=document.createElement('select');input.add(new Option('Use whole item',''));
      const action=bootstrap.actions.find(item=>item.id===selected.action?.action_id);
      const field=findResponseField(action?.response_fields||[],selected.properties?.binding);
      responseItemPaths(field?.children||[]).forEach(v=>input.add(new Option(v,v)));
    }
    else {input=document.createElement('input');input.type=property.type==='boolean'?'checkbox':property.type==='number'?'number':property.type==='color'?'color':'text'}
    const value=propertySource[property.name]??selected.properties?.[property.name];
    if(input.type==='checkbox')input.checked=value===true;else input.value=value??'';
    input.oninput=()=>{checkpoint();propertySource[property.name]=input.type==='checkbox'?input.checked:input.type==='number'?(input.value===''?null:Number(input.value)):input.value;renderCanvas()};
    label.appendChild(input);host.appendChild(label);
  });
  renderActions($('actionSearch').value);
  $('successRoute').value=selected.action?.on_success_route||'';
  $('errorRoute').value=selected.action?.on_error_route||'';
  $('successMessage').value=selected.action?.success_message||'';
  $('errorMessage').value=selected.action?.error_message||'';
  renderFlowSteps();
}
function renderActions(filter=''){
  const select=$('actionSelect'), current=selected?.action?.action_id||'';select.innerHTML='<option value="">No action</option>';
  bootstrap.actions.filter(a=>`${a.id} ${a.target} ${a.operation}`.toLowerCase().includes(filter.toLowerCase()))
    .forEach(a=>select.add(new Option(`${a.id} · ${a.target}`,a.id)));
  select.value=current; renderArguments();
}
function renderArguments(){
  const host=$('arguments');host.innerHTML='';const action=bootstrap.actions.find(a=>a.id===selected?.action?.action_id);if(!action)return;
  const fields=allNodes(schema.root).filter(node=>node.type==='appTextField');
  action.parameters.forEach(parameter=>{
    renderParameter(parameter,selected.action.arguments?.[parameter.name],host,value=>{
      selected.action.arguments||={};selected.action.arguments[parameter.name]=value;
    },fields);
  });
}
function renderFlowSteps(){
  const host=$('flowSteps');host.innerHTML='';selected.actions||=[];
  selected.actions.forEach((binding,index)=>{
    const step=document.createElement('div');step.className='flow-step';
    const head=document.createElement('div');head.className='flow-step-head';
    const actionSelect=document.createElement('select');
    bootstrap.actions.forEach(action=>actionSelect.add(new Option(`${action.id} · ${action.target}`,action.id)));
    actionSelect.value=binding.action_id;
    actionSelect.onchange=()=>{const action=bootstrap.actions.find(item=>item.id===actionSelect.value);checkpoint();selected.actions[index]={action_id:action.id,method:'execute',arguments:defaultArguments(action),run_when:binding.run_when||'always'};renderInspector()};
    const remove=document.createElement('button');remove.textContent='×';remove.title='Remove step';
    remove.onclick=()=>{checkpoint();selected.actions.splice(index,1);renderInspector()};
    head.appendChild(actionSelect);head.appendChild(remove);step.appendChild(head);
    const condition=document.createElement('select');
    [['always','Always'],['previousSuccess','After previous success'],['previousError','After previous error']].forEach(([value,label])=>condition.add(new Option(label,value)));
    condition.value=binding.run_when||'always';condition.onchange=()=>{checkpoint();binding.run_when=condition.value};
    const conditionLabel=document.createElement('label');conditionLabel.textContent='Run condition';conditionLabel.appendChild(condition);step.appendChild(conditionLabel);
    const feedback=[['success_message','Success feedback'],['error_message','Error feedback'],['on_success_route','Success route'],['on_error_route','Error route']];
    feedback.forEach(([key,title])=>{const label=document.createElement('label');label.textContent=title;const input=document.createElement('input');input.value=binding[key]||'';input.onchange=()=>{checkpoint();binding[key]=input.value||undefined};label.appendChild(input);step.appendChild(label)});
    const action=bootstrap.actions.find(item=>item.id===binding.action_id),fields=allNodes(schema.root).filter(node=>node.type==='appTextField');
    action?.parameters.forEach(parameter=>renderParameter(parameter,binding.arguments?.[parameter.name],step,value=>{binding.arguments||={};binding.arguments[parameter.name]=value},fields));
    host.appendChild(step);
  });
}
function renderParameter(parameter,current,host,setValue,fields){
  if(parameter.is_list){
    const group=document.createElement('div');group.className='parameter-group';
    group.innerHTML=`<div class="parameter-title">${parameter.name} · ${parameter.type}</div>`;
    if(parameter.children?.length){
      const items=Array.isArray(current)?current:[];
      items.forEach((item,index)=>{
        const object=item&&typeof item==='object'&&!Array.isArray(item)?item:{};items[index]=object;
        const row=document.createElement('div');row.className='list-item';
        const remove=document.createElement('button');remove.className='remove-item';remove.textContent='×';
        remove.onclick=()=>{checkpoint();items.splice(index,1);setValue(items);renderInspector()};row.appendChild(remove);
        parameter.children.forEach(child=>renderParameter(child,object[child.name],row,value=>{object[child.name]=value;setValue(items)},fields));
        group.appendChild(row);
      });
      const add=document.createElement('button');add.className='add-item';add.textContent='Add item';
      add.onclick=()=>{checkpoint();items.push(defaultObject(parameter.children,fields));setValue(items);renderInspector()};group.appendChild(add);
    }else{
      const input=document.createElement('textarea');input.rows=3;input.placeholder='JSON array';input.value=JSON.stringify(Array.isArray(current)?current:[]);
      input.onchange=()=>{try{const value=JSON.parse(input.value);if(!Array.isArray(value))throw new Error('Expected an array');checkpoint();setValue(value);setStatus('List updated')}catch(error){setStatus(error.message,true)}};
      group.appendChild(input);
    }
    host.appendChild(group);return;
  }
  if(parameter.children?.length){
    const group=document.createElement('div');group.className='parameter-group';
    group.innerHTML=`<div class="parameter-title">${parameter.name} · ${parameter.type}</div>`;
    const object=current&&typeof current==='object'&&!Array.isArray(current)?current:defaultObject(parameter.children,fields);
    setValue(object);
    parameter.children.forEach(child=>renderParameter(child,object[child.name],group,value=>{object[child.name]=value;setValue(object)},fields));
    host.appendChild(group);return;
  }
  const label=document.createElement('label');label.textContent=`${parameter.name} · ${parameter.type}`;
  const sourceId=fieldSource(current),source=document.createElement('select');source.add(new Option('Literal value',''));
  if(isPrimitive(parameter.type))fields.forEach(field=>source.add(new Option(`Field: ${field.properties?.label||field.id}`,field.id)));
  source.value=sourceId||'';
  const input=document.createElement('input');input.value=sourceId?'':current??'';
  input.placeholder=`Literal ${parameter.type} value`;input.hidden=!!sourceId;
  source.onchange=()=>{checkpoint();input.hidden=!!source.value;setValue(source.value?`$${source.value}.value`:typedValue(input.value,parameter.type))};
  input.onchange=()=>{checkpoint();setValue(typedValue(input.value,parameter.type))};
  label.appendChild(source);label.appendChild(input);host.appendChild(label);
}
function allNodes(root){return [root,...(root.children||[]).flatMap(allNodes)]}
function responsePaths(fields,prefix='data'){
  return fields.flatMap(field=>{
    const path=`${prefix}.${field.name}`;
    if(field.is_list||!field.children?.length)return [path];
    return responsePaths(field.children,path);
  });
}
function responseListPaths(fields,prefix='data'){
  return fields.flatMap(field=>{const path=`${prefix}.${field.name}`;if(field.is_list)return [path];return responseListPaths(field.children||[],path)});
}
function findResponseField(fields,path,prefix='data'){
  for(const field of fields){const current=`${prefix}.${field.name}`;if(current===path)return field;const nested=findResponseField(field.children||[],path,current);if(nested)return nested}
  return null;
}
function responseItemPaths(fields,prefix=''){
  return fields.flatMap(field=>{const path=prefix?`${prefix}.${field.name}`:field.name;if(field.is_list||!field.children?.length)return [path];return responseItemPaths(field.children,path)});
}
function fieldSource(value){const match=typeof value==='string'&&value.match(/^\$(.+)\.value$/);return match?match[1]:null}
function normalize(value){return `${value||''}`.toLowerCase().replace(/[^a-z0-9]/g,'')}
function defaultArguments(action){
  const fields=allNodes(schema.root).filter(node=>node.type==='appTextField'), result={};
  action.parameters.forEach(parameter=>result[parameter.name]=defaultParameter(parameter,fields,action.parameters.length===1));
  return result;
}
function defaultParameter(parameter,fields,single=false){
  if(parameter.is_list)return [];
  if(parameter.children?.length)return defaultObject(parameter.children,fields);
  const parameterName=normalize(parameter.name);
  const exact=fields.find(field=>[field.id,field.properties?.label].some(value=>normalize(value)===parameterName));
  const related=fields.find(field=>[field.id,field.properties?.label].some(value=>parameterName.endsWith(normalize(value))||normalize(value).endsWith(parameterName)));
  const field=exact||related||(single&&fields.length===1?fields[0]:null);
  return field?`$${field.id}.value`:defaultLiteral(parameter.type);
}
function defaultObject(parameters,fields){const value={};parameters.forEach(parameter=>value[parameter.name]=defaultParameter(parameter,fields));return value}
function isPrimitive(type){return ['String','int','double','num','bool','dynamic'].includes(type)}
function defaultLiteral(type){if(type==='String'||type==='dynamic')return '';if(type==='bool')return false;return null}
function typedValue(value,type){
  if(value.startsWith('$'))return value;
  if(type==='int'){const parsed=parseInt(value);return Number.isNaN(parsed)?null:parsed}
  if(type==='double'||type==='num'){const parsed=Number(value);return value.trim()===''||Number.isNaN(parsed)?null:parsed}
  if(type==='bool')return value.toLowerCase()==='true';
  return value;
}

function bindControls(){
  $('componentSearch').oninput=e=>renderPalette(e.target.value);
  $('canvas').ondragover=e=>e.preventDefault(); $('canvas').ondrop=e=>{e.preventDefault();if(draggedType)addNode(draggedType);else if(draggedNodeId)moveNode(draggedNodeId,schema.root.id)};
  document.querySelectorAll('.breakpoints button').forEach(button=>button.onclick=()=>{
    document.querySelectorAll('.breakpoints button').forEach(item=>item.classList.remove('active'));button.classList.add('active');
    $('device').style.width=`${button.dataset.width}px`;render();
  });
  const updateScreen=()=>{checkpoint();render()};
  $('screenName').onchange=updateScreen;$('featureName').onchange=updateScreen;$('route').onchange=updateScreen;
  $('screens').onchange=async e=>{
    if(!e.target.value)return;
    try{schema=await request(`/api/screens/${encodeURIComponent(e.target.value)}`);selected=null;history=[];future=[];syncScreenFields();renderBreakpoints();render();updateHistoryButtons()}catch(error){setStatus(error.message,true)}
  };
  $('newScreen').onclick=newScreen;$('duplicateScreen').onclick=duplicateScreen;$('deleteScreen').onclick=deleteScreen;
  $('applyTemplate').onclick=applyTemplate;$('saveTemplate').onclick=saveTemplate;
  $('nodeId').onchange=e=>{checkpoint();selected.id=e.target.value;render()};
  $('breakpointOverride').onchange=renderInspector;
  $('actionSearch').oninput=e=>renderActions(e.target.value);
  $('actionSelect').onchange=e=>{checkpoint();const watches=['appLoadingIndicator','stateText','stateList','stateGrid'].includes(selected.type),action=bootstrap.actions.find(item=>item.id===e.target.value);selected.action=action?{action_id:action.id,method:watches?'watch':'execute',arguments:watches?{}:defaultArguments(action)}:undefined;renderInspector()};
  $('successRoute').onchange=e=>{if(selected.action){checkpoint();selected.action.on_success_route=e.target.value||undefined}};
  $('errorRoute').onchange=e=>{if(selected.action){checkpoint();selected.action.on_error_route=e.target.value||undefined}};
  $('successMessage').onchange=e=>{if(selected.action){checkpoint();selected.action.success_message=e.target.value||undefined}};
  $('errorMessage').onchange=e=>{if(selected.action){checkpoint();selected.action.error_message=e.target.value||undefined}};
  $('addFlowStep').onclick=()=>{const action=bootstrap.actions[0];if(!action)return setStatus('Generate an API action first.',true);checkpoint();selected.actions||=[];selected.actions.push({action_id:action.id,method:'execute',arguments:defaultArguments(action),run_when:'previousSuccess'});renderInspector()};
  $('undo').onclick=undo;$('redo').onclick=redo;$('duplicate').onclick=duplicateSelected;
  $('remove').onclick=removeSelected;
  $('save').onclick=()=>persist(false);$('generate').onclick=()=>persist(true);
  document.onkeydown=e=>{
    if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='z'){e.preventDefault();e.shiftKey?redo():undo()}
    else if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='y'){e.preventDefault();redo()}
    else if(e.key==='Delete'&&document.activeElement?.tagName!=='INPUT'){removeSelected()}
  };
  updateHistoryButtons();
}
async function persist(generate){
  render();setStatus(generate?'Generating…':'Saving…');
  try{
    const result=await request(generate?'/api/generate':'/api/screens',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(schema)});
    if(![...$('screens').options].some(option=>option.value===schema.name))$('screens').add(new Option(schema.name,schema.name));
    $('screens').value=schema.name;
    setStatus(result.message||'Saved');
  }catch(error){setStatus(error.message,true)}
}
function setStatus(message,error=false){$('status').textContent=message;$('status').style.color=error?'#ff9dad':'#98a3b6'}
init().catch(error=>setStatus(error.message,true));
''';
}
