import {readFileSync,readdirSync,existsSync} from 'node:fs';
import {join} from 'node:path';
const root=new URL('../',import.meta.url).pathname;
const fail=(m)=>{console.error('FAIL:',m);process.exitCode=1};
const ok=(m)=>console.log('ok:',m);
const compactCode=(source)=>source.replace(/\s+/g,'');
const hasCode=(source,fragment)=>compactCode(source).includes(compactCode(fragment));
const manifest=JSON.parse(readFileSync(join(root,'build/manifest.json'),'utf8'));
const pkg=JSON.parse(readFileSync(join(root,'package.json'),'utf8'));
const init=readFileSync(join(root,'src/init.lua'),'utf8');
if(pkg.version!==manifest.version || !hasCode(init,`BobloUI.Version="${manifest.version}"`)) fail('package/manifest/runtime versions differ'); else ok(`version aligned: ${manifest.version}`);
if(Object.keys(manifest.components).length!==16) fail('manifest must expose exactly 16 constructors'); else ok('16 canonical constructors');
const section=readFileSync(join(root,'src/shell/Section.lua'),'utf8');
for(const c of Object.values(manifest.components)) if(!section.includes(`function Section:${c.method}`)) fail(`Section missing ${c.method}`);
const windowCoreSrc=readFileSync(join(root,'src/shell/Window.lua'),'utf8');
const tabSrc=readFileSync(join(root,'src/shell/Tab.lua'),'utf8');
const windowChromeSrc=readFileSync(join(root,'src/shell/WindowChrome.lua'),'utf8');
const windowLayoutSrc=readFileSync(join(root,'src/shell/WindowLayout.lua'),'utf8');
const motionSrc=readFileSync(join(root,'src/kernel/Motion.lua'),'utf8');
const windowSrc=[windowCoreSrc,tabSrc,windowChromeSrc.replaceAll('WindowChrome:','Window:'),windowLayoutSrc.replaceAll('WindowLayout:','Window:')].join('\n');
for(const c of Object.values(manifest.components)) if(!tabSrc.includes(`function Tab:${c.method}`)) fail(`Tab missing ${c.method}`);
const all=[]; const walk=(d)=>{for(const n of readdirSync(d,{withFileTypes:true})){const p=join(d,n.name); if(n.isDirectory())walk(p); else if(n.name.endsWith('.lua'))all.push([p,readFileSync(p,'utf8')])}}; walk(join(root,'src'));
for(const [p,s] of all){
  if(/RenderStepped/.test(s)) fail(`RenderStepped forbidden: ${p}`);
  if(p.indexOf('/runtime/Env.lua')<0 && /\b(gethui|writefile|readfile|setclipboard|protect_gui)\b/.test(s)) fail(`executor global outside Env: ${p}`);
}
const bundle=readFileSync(join(root,'dist/BobloUI.lua'),'utf8');
if(!bundle.includes('Source: https://github.com/bobloscript/BobloUI/blob/main/dist/BobloUI.lua') || bundle.includes('github.com/bobloscript/scripts')) fail('bundle still targets the old scripts repository'); else ok('bundle targets the standalone BobloUI repository');
if(bundle.includes('__modules["schema/Manifest"]')) fail('full Manifest leaked into production bundle'); else ok('full Manifest tree-shaken');
if(!bundle.includes('__modules["runtime/RuntimeManifest"]')) fail('RuntimeManifest missing from bundle'); else ok('RuntimeManifest bundled');
if(/AddMultiDropdown|AddLabel|AddTextbox/.test(section)) fail('non-canonical constructor leaked into Section API'); else ok('no constructor aliases');
const llms=readFileSync(join(root,'llms.txt'),'utf8');
if(!llms.includes('RULES') || !llms.includes('globally unique Id') || !llms.includes('NO AddLabel')) fail('llms.txt missing AI guardrails'); else ok('AI guardrails generated');
const types=readFileSync(join(root,'src/runtime/Types.lua'),'utf8');
for(const name of Object.keys(manifest.components)) if(!types.includes(`export type ${name}Options`)) fail(`generated types missing ${name}Options`);
if(!types.includes('Title: string') || !types.includes('Min: number')) fail('required fields did not reach generated Luau types'); else ok('generated Luau types include required fields');
const build=readFileSync(join(root,'src/schema/Build.lua'),'utf8');
if(!build.includes('Validate.Collect') || !build.includes('UI:Build validation failed')) fail('declarative build does not prevalidate all control options'); else ok('declarative pre-validation wired');
const configSrc=readFileSync(join(root,'src/services/Config.lua'),'utf8');
const dialogSectionSrc=readFileSync(join(root,'src/services/DialogSection.lua'),'utf8');
if(!/self\._orphans\[entry\.Id\]\s*=\s*nil/.test(configSrc)) fail('config pending values do not clear orphan entries when controls mount'); else ok('config pending/orphan lifecycle wired');
if(!windowSrc.includes('function Tab:SetIcon') || !windowSrc.includes('function Tab:SetBadge')) fail('Tab Icon/Badge public API incomplete'); else ok('Tab Icon/Badge API wired');
if(!windowSrc.includes('TwoColumnMinWidth') || !windowSrc.includes('ColumnGap') || !windowSrc.includes('self._sectionHost.AbsoluteSize.X')) fail('responsive section width calculation missing'); else ok('responsive section width calculation wired');
if(windowSrc.includes('Size=UDim2.new(0.5,-8') || windowSrc.includes('Position=UDim2.new(0.5,8')) fail('legacy half-scale section columns still present'); else ok('legacy half-scale columns removed');
if(!windowSrc.includes('self._pagePadding.PaddingLeft = UDim.new(0, 0)') || !windowSrc.includes('self._sectionHost.Size = UDim2.new(1, -(pagePadding * 2)')) fail('page horizontal bounds are not explicit'); else ok('page horizontal bounds explicit');
const baseControl=readFileSync(join(root,'src/controls/Base.lua'),'utf8');
if(!hasCode(baseControl,'section._janitor:Add(self,"Destroy",self)') || !hasCode(baseControl,'self._section._janitor:Release(self)')) fail('Section does not own controls through Destroy lifecycle'); else ok('dynamic control lifecycle ownership wired');
if(!hasCode(baseControl,'self._disabled=self._manualDisabled') || !hasCode(baseControl,'return self._manualDisabled or not self._dependencyEnabled')) fail('disabled controls are not effective before lazy mount'); else ok('disabled state is effective before lazy mount');
if(!dialogSectionSrc.includes('function DialogSection:_controlParent') || !dialogSectionSrc.includes('function DialogSection:_refreshSeparators')) fail('DialogSection control-container contract incomplete'); else ok('DialogSection control-container contract complete');
for(const file of ['api.json','schema.json','llms.txt','llms-full.txt','CHANGELOG.md','docs/obsidian-gap-analysis.md','docs/p1-p2-services.md','tests/01-full-smoke.lua','tests/02-all-features-smoke.lua','tests/03-0.11-expansion-smoke.lua','tests/04-loader-diagnostic.lua','tests/BobloUI-Full-Diagnostic.lua','tests/leak.lua','examples/basic.lua','examples/declarative.lua','examples/all-features.lua','examples/p1-p2-showcase.lua']) if(!existsSync(join(root,file))) fail(`missing release artifact ${file}`);
if(!process.exitCode) console.log('static checks passed');

// 0.10 capability contract ----------------------------------------------------
const sectionSrc=readFileSync(join(root,'src/shell/Section.lua'),'utf8');
const iconSrc=readFileSync(join(root,'src/primitives/Icon.lua'),'utf8');
const lucideSrc=readFileSync(join(root,'src/primitives/Lucide.lua'),'utf8');
const tokensSrc=readFileSync(join(root,'src/kernel/Tokens.lua'),'utf8');
const themeSrc=readFileSync(join(root,'src/kernel/Theme.lua'),'utf8');
const settingsSrc=readFileSync(join(root,'src/services/Settings.lua'),'utf8');
const paletteSrc=readFileSync(join(root,'src/services/Palette.lua'),'utf8');
const dialogSrc=readFileSync(join(root,'src/services/Dialog.lua'),'utf8');
const sheetSrc=readFileSync(join(root,'src/primitives/Sheet.lua'),'utf8');
const dropdownSrc=readFileSync(join(root,'src/controls/Dropdown.lua'),'utf8');
const validateSrc=readFileSync(join(root,'src/runtime/Validate.lua'),'utf8');
const interactionsSrc=readFileSync(join(root,'src/services/Interactions.lua'),'utf8');
const envSrc=readFileSync(join(root,'src/runtime/Env.lua'),'utf8');
const createSrc=readFileSync(join(root,'src/runtime/Create.lua'),'utf8');
const notifySrc=readFileSync(join(root,'src/services/Notify.lua'),'utf8');
const soundSrc=readFileSync(join(root,'src/services/Sound.lua'),'utf8');
const navigationSrc=readFileSync(join(root,'src/services/Navigation.lua'),'utf8');

const lucideVendorFiles=['source.lua','spritesheets/1.png','spritesheets/2.png','LUCIDE-LICENSE','ROBLOX-PORT-LICENSE','icon-index.txt'];
for(const file of lucideVendorFiles) if(!existsSync(join(root,'vendor/lucide',file))) fail(`vendored Lucide file missing: ${file}`);
const lucideNames=readFileSync(join(root,'vendor/lucide/icon-index.txt'),'utf8').trim().split(/\r?\n/);
if(lucideNames.length!==1756 || new Set(lucideNames).size!==1756) fail('vendored Lucide index must contain 1,756 unique names'); else ok('1,756 unique Lucide names vendored');
const atlasEntries=[...lucideSrc.matchAll(/\{\s*([12]),\s*\{\s*(\d+),\s*(\d+)\s*\},\s*\{\s*(\d+),\s*(\d+)\s*\}\s*\}/g)];
const pngSize=(file)=>{const png=readFileSync(file);return {width:png.readUInt32BE(16),height:png.readUInt32BE(20)}};
const atlasSizes=[pngSize(join(root,'vendor/lucide/spritesheets/1.png')),pngSize(join(root,'vendor/lucide/spritesheets/2.png'))];
const invalidAtlasEntry=atlasEntries.find(([,sheet,w,h,x,y])=>Number(w)!==24 || Number(h)!==24 || Number(x)<0 || Number(y)<0 || Number(x)+Number(w)>atlasSizes[Number(sheet)-1].width || Number(y)+Number(h)>atlasSizes[Number(sheet)-1].height);
if(atlasEntries.length!==lucideNames.length || invalidAtlasEntry) fail('Lucide atlas mapping is incomplete or outside spritesheet bounds'); else ok('all Lucide atlas rectangles fit the two source PNGs');
if(!iconSrc.includes('require("@primitives/Lucide")') || !iconSrc.includes('function Icon.SetAtlasUrls') || !iconSrc.includes('function Icon.GetStatus') || !iconSrc.includes('function Icon.Retry') || !iconSrc.includes('function Icon.Resolve')) fail('Lucide GitHub IconProvider API incomplete'); else ok('Lucide GitHub IconProvider API wired');
if(/\b(?:writefile|readfile|getcustomasset|getsynasset)\b/.test(lucideSrc) || /game:HttpGet/.test(lucideSrc)) fail('Lucide bypasses the Env capability boundary'); else ok('Lucide external/file IO is isolated behind Env');
if(!envSrc.includes('function Env.HttpGet') || !envSrc.includes('function Env.GetCustomAsset') || !envSrc.includes('CustomAsset = customAsset ~= nil')) fail('Env GitHub/custom-asset capabilities incomplete'); else ok('Env GitHub/custom-asset capabilities wired');
if(!lucideSrc.includes('raw.githubusercontent.com/bobloscript/BobloUI/main/dist/assets/bobloui/lucide-1.png') || !lucideSrc.includes('raw.githubusercontent.com/bobloscript/BobloUI/main/dist/assets/bobloui/lucide-2.png') || !lucideSrc.includes('function Lucide.SetAtlasUrls') || !lucideSrc.includes('function Lucide.Prepare') || !lucideSrc.includes('validatePng')) fail('Lucide GitHub atlas/cache contract incomplete'); else ok('Lucide GitHub atlas/cache contract wired');
if(lucideSrc.includes('rbxassetid://')) fail('Lucide runtime contains a Roblox asset ID'); else ok('Lucide runtime is Roblox asset-ID free');
for(const [sourceName,distName] of [['1.png','lucide-1.png'],['2.png','lucide-2.png']]){
  const sourcePath=join(root,'vendor/lucide/spritesheets',sourceName);
  const distPath=join(root,'dist/assets/bobloui',distName);
  if(!existsSync(distPath) || !readFileSync(sourcePath).equals(readFileSync(distPath))) fail(`generated GitHub atlas differs from vendored source: ${distName}`); else ok(`generated GitHub atlas preserved: ${distName}`);
}
if(!lucideSrc.includes('nameToIndex[name]') || !lucideSrc.includes('Lucide.Count = #iconIndices')) fail('Lucide lookup index/count missing'); else ok('Lucide name lookup is indexed');
if(!existsSync(join(root,'dist/THIRD_PARTY_LICENSES.txt')) || !bundle.includes('Lucide Icons and Contributors') || !bundle.includes('Copyright (c) 2025 deividcomsono')) fail('generated bundle/license artifact misses third-party notices'); else ok('third-party notices preserved in bundle');
if(!windowChromeSrc.includes('drawToolbarIcon') || !windowChromeSrc.includes('"sun-moon"') || !settingsSrc.includes('Icon = "settings-2"') || !notifySrc.includes('local GLYPH =') || !dialogSrc.includes('function Dialog:_title')) fail('Lucide visual pass is incomplete'); else ok('Lucide visual pass covers chrome, settings, notifications, and dialogs');

if(!tokensSrc.includes('MinSectionWidth') || !tokensSrc.includes('ControlStackBreakpoint') || !tokensSrc.includes('ControlGridMinWidth')) fail('responsive breakpoint tokens incomplete'); else ok('responsive section/control/grid breakpoints wired');
if(!hasCode(sectionSrc,'Span=span') || !hasCode(sectionSrc,'Layout=layout') || !sectionSrc.includes('function Section:SetSpan') || !sectionSrc.includes('function Section:SetLayout')) fail('Section span/layout API incomplete'); else ok('Section Span + Stack/Grid/Auto API wired');
if(!baseControl.includes('_adaptive') || !sectionSrc.includes('ControlStackBreakpoint') || !sectionSrc.includes('_updateAdaptiveControls')) fail('adaptive control stacking missing'); else ok('adaptive controls delegated to Section');
if(!windowSrc.includes('function Tab:SetGroup') || !windowSrc.includes('_ensureGroupHeader')) fail('tab groups missing'); else ok('tab groups wired');
if(!hasCode(dropdownSrc,'Style=="Segmented"') || !dropdownSrc.includes('_mountSegmented')) fail('segmented control mode missing'); else ok('segmented dropdown mode wired');
if(!hasCode(validateSrc,'typeName=="Dropdown" and options.Options==nil and options.Values==nil and options.Source==nil')) fail('Dropdown runtime validation does not accept Options, Values, or Source'); else ok('Dropdown runtime accepts Options, Values, or Source');
if(!themeSrc.includes('function Theme:SetToken') || !themeSrc.includes('function Theme:ResetOverrides') || !themeSrc.includes('function Theme:Export') || !themeSrc.includes('function Theme:Import') || !themeSrc.includes('function Theme:SetHighContrast')) fail('advanced theme API incomplete'); else ok('theme overrides/export/import/high-contrast wired');
const darkThemeSrc=readFileSync(join(root,'src/themes/Dark.lua'),'utf8');
const lightThemeSrc=readFileSync(join(root,'src/themes/Light.lua'),'utf8');
const themeKeys=(source)=>[...source.matchAll(/^\s*([A-Za-z][A-Za-z0-9]*)\s*=/gm)].map(match=>match[1]);
const themeColorKeys=(source)=>[...source.matchAll(/^\s*([A-Za-z][A-Za-z0-9]*)\s*=\s*hex\(/gm)].map(match=>match[1]);
if(existsSync(join(root,'src/themes/OLED.lua')) || existsSync(join(root,'src/themes/Midnight.lua')) || !hasCode(init,'Palettes={Dark=Dark,Light=Light}')) fail('bundled themes must be exactly Dark + Light'); else ok('only Dark + Light presets are bundled');
if(themeColorKeys(darkThemeSrc).length!==26 || themeColorKeys(lightThemeSrc).length!==26 || themeKeys(darkThemeSrc).length!==27 || themeKeys(lightThemeSrc).length!==27 || !hasCode(darkThemeSrc,'ScrimTransparency=0.52') || !hasCode(lightThemeSrc,'ScrimTransparency=0.58') || darkThemeSrc.includes('Shadow') || lightThemeSrc.includes('Shadow')) fail('Dark/Light contract must contain 26 base colors plus ScrimTransparency without Shadow'); else ok('Dark/Light expose 26 base colors plus numeric scrim alpha');
const utilSrc=readFileSync(join(root,'src/runtime/Util.lua'),'utf8');
const layerThemeSrc=readFileSync(join(root,'src/kernel/Layer.lua'),'utf8');
const buttonThemeSrc=readFileSync(join(root,'src/controls/Button.lua'),'utf8');
const badgeThemeSrc=readFileSync(join(root,'src/primitives/Badge.lua'),'utf8');
const toggleThemeSrc=readFileSync(join(root,'src/controls/Toggle.lua'),'utf8');
const loadingThemeSrc=readFileSync(join(root,'src/services/Loading.lua'),'utf8');
const sliderThemeSrc=readFileSync(join(root,'src/controls/Slider.lua'),'utf8');
const codeThemeSrc=readFileSync(join(root,'src/controls/Code.lua'),'utf8');
const themePersistenceSrc=readFileSync(join(root,'src/services/ThemeManager.lua'),'utf8');
const semanticForegrounds=['TextOnAccent','TextOnAccentButton','TextOnSuccess','TextOnWarning','TextOnError','TextOnInfo'];
if(!utilSrc.includes('function Util.contrastRatio') || !utilSrc.includes('linearChannel') || semanticForegrounds.some(token=>!themeSrc.includes(`palette.${token}`))) fail('WCAG semantic foreground derivation incomplete'); else ok('WCAG foreground tokens cover accent and every status color');
const parseThemeColors=(source)=>Object.fromEntries([...source.matchAll(/^\s*([A-Za-z][A-Za-z0-9]*)\s*=\s*hex\("#([0-9A-Fa-f]{6})"\)/gm)].map(([,token,hex])=>{const value=Number.parseInt(hex,16);return [token,[(value>>16)/255,((value>>8)&255)/255,(value&255)/255]]}));
const mixColor=(from,to,alpha)=>from.map((channel,index)=>channel+(to[index]-channel)*alpha);
const linearChannel=(channel)=>channel<=0.04045?channel/12.92:((channel+0.055)/1.055)**2.4;
const relativeLuminance=(color)=>0.2126*linearChannel(color[0])+0.7152*linearChannel(color[1])+0.0722*linearChannel(color[2]);
const contrastRatio=(first,second)=>{const a=relativeLuminance(first),b=relativeLuminance(second);return (Math.max(a,b)+0.05)/(Math.min(a,b)+0.05)};
const black=[0,0,0],white=[1,1,1];
const bestText=(background)=>contrastRatio(background,black)>=contrastRatio(background,white)?black:white;
let contrastFailure=null;
for(const [name,source] of [['Dark',darkThemeSrc],['Light',lightThemeSrc]]){
  const palette=parseThemeColors(source);
  const accentButton=mixColor(palette.Accent,palette.Surface,0.50);
  const errorText=bestText(palette.Error);
  const checks={
    Accent: [palette.Accent,bestText(palette.Accent)],
    AccentButton: [accentButton,bestText(accentButton)],
    AccentButtonHover: [mixColor(palette.Accent,palette.Surface,0.40),bestText(accentButton)],
    AccentButtonPressed: [mixColor(palette.Accent,palette.Surface,0.58),bestText(accentButton)],
    Success: [palette.Success,bestText(palette.Success)],
    Warning: [palette.Warning,bestText(palette.Warning)],
    Error: [palette.Error,errorText],
    ErrorHover: [mixColor(palette.Error,white,0.08),errorText],
    ErrorPressed: [mixColor(palette.Error,black,0.05),errorText],
    Info: [palette.Info,bestText(palette.Info)],
  };
  for(const [token,[background,foreground]] of Object.entries(checks)) if(contrastRatio(background,foreground)<4.5) contrastFailure=`${name}.${token} ${contrastRatio(background,foreground).toFixed(2)}:1`;
}
if(contrastFailure) fail(`theme foreground contrast below WCAG AA: ${contrastFailure}`); else ok('Dark/Light semantic foregrounds remain at least 4.5:1 across button states');
const componentThemeSources=[buttonThemeSrc,badgeThemeSrc,toggleThemeSrc,dialogSrc,loadingThemeSrc].join('\n');
if(componentThemeSources.includes('"AccentText"') || !buttonThemeSrc.includes('TextOnAccentButton') || !buttonThemeSrc.includes('TextOnError') || !badgeThemeSrc.includes('TextOnSuccess') || !badgeThemeSrc.includes('TextOnWarning') || !badgeThemeSrc.includes('TextOnInfo') || !toggleThemeSrc.includes('TextOnAccent')) fail('components still share an incorrect accent foreground'); else ok('components consume exact semantic foreground tokens');
if(!buttonThemeSrc.includes('AccentButtonPressed') || !buttonThemeSrc.includes('ErrorPressed') || !dialogSrc.includes('AccentButtonPressed') || !dialogSrc.includes('MouseButton1Down')) fail('primary/danger pressed-state colors are not rendered'); else ok('primary and danger buttons render hover and pressed states');
const hardcodedScrim=all.find(([path,source])=>!path.includes('/themes/') && !path.endsWith('/kernel/Theme.lua') && !path.endsWith('/services/ThemeManager.lua') && /ScrimTransparency\s*=\s*0\./.test(source));
if(!hasCode(init,'Layer.new(id,input,theme)') || !layerThemeSrc.includes('self._theme:Bind(catcher, "BackgroundColor3", "Scrim")') || !layerThemeSrc.includes('self._theme:Bind(catcher, "BackgroundTransparency", "ScrimTransparency")') || hardcodedScrim) fail('modal scrim bypasses live theme tokens'); else ok('modal scrim color and alpha are live theme bindings');
if(!themePersistenceSrc.includes('type(value) == "number"') || !settingsSrc.includes('__settings.token.ScrimTransparency') || !themeSrc.includes('math.clamp(value, 0, 1)')) fail('numeric scrim token persistence/editor support incomplete'); else ok('numeric scrim alpha persists and is editable');
if(!sliderThemeSrc.includes('local bubbleStroke') || !hasCode(sliderThemeSrc,'w:_bind(bubbleStroke,{Color="Border"})') || !codeThemeSrc.includes('local copyStroke') || !hasCode(codeThemeSrc,'w:_bind(copyStroke,{Color="Border"})')) fail('raised controls can disappear into Light surfaces'); else ok('raised Slider and Code controls have Light-safe borders');
for(const needle of ['themeEditor','_buildConfig','_refreshFavorites','_refreshKeybinds','keyboardNavigation','uiSounds']) if(!settingsSrc.includes(needle)) fail(`Settings center missing ${needle}`);
if(settingsSrc.includes('themeEditor') && settingsSrc.includes('_refreshFavorites') && settingsSrc.includes('_refreshKeybinds')) ok('built-in Settings center wired');
if(!paletteSrc.includes('"#"') || !paletteSrc.includes('"*"') || !hasCode(paletteSrc,'Kind="Config"') || !hasCode(paletteSrc,'Kind="Favorite"')) fail('palette config/favorite providers missing'); else ok('palette providers > @ # * wired');
if(!dialogSrc.includes('function Dialog:Choice')) fail('Choice dialog missing'); else ok('Choice dialog wired');
if(!sectionSrc.includes('function Section:AddCustom') || !windowSrc.includes('function Tab:AddCustom') || !init.includes('RegisterControl')) fail('custom control registry incomplete'); else ok('custom-control extension API wired');
if(!sheetSrc.includes('KeyboardHeight') || !sheetSrc.includes('SafeArea') || !hasCode(sheetSrc,'dy>60')) fail('mobile sheet safe-area/keyboard/swipe handling incomplete'); else ok('mobile sheet safe-area + keyboard + swipe wired');
for(const needle of ['meta.collapsed = collapsed','meta.geometry = serialize(geometry)','meta.reducedMotion =','meta.keyboardNavigation =','meta.uiSounds =','meta.soundVolume =']) if(!configSrc.includes(needle)) fail(`config UI-preference persistence missing ${needle}`);
if(configSrc.includes('meta.collapsed = collapsed') && configSrc.includes('meta.geometry = serialize(geometry)')) ok('config persists layout + UI preferences');
if(!windowSrc.includes('function Window:SetLocked') || !windowSrc.includes('function Window:ResetGeometry') || !windowSrc.includes('function Window:Minimize') || !windowSrc.includes('_minimizeButton')) fail('window behavior API/header incomplete'); else ok('window lock/geometry/minimize/restore wired');
if(!envSrc.includes('GetClipboard') || !baseControl.includes('function Base:PasteValue') || !interactionsSrc.includes('Paste value')) fail('copy/paste value UX incomplete'); else ok('copy + optional clipboard paste wired');
if(!notifySrc.includes('SetProgress') || !notifySrc.includes('_progressFill')) fail('notification progress updates missing'); else ok('notification progress updates wired');
if(!soundSrc.includes('function Sound:Register') || !soundSrc.includes('function Sound:Play') || !hasCode(init,'window.Sound=sound')) fail('optional UI sound service missing'); else ok('optional UI sound registry wired');
if(!navigationSrc.includes('function Navigation:Move') || !navigationSrc.includes('ButtonA') || !navigationSrc.includes('DPadDown') || !hasCode(init,'window.Navigation=navigation')) fail('keyboard/gamepad navigation service missing'); else ok('keyboard + gamepad navigation wired');
const schemaObj=JSON.parse(readFileSync(join(root,'schema.json'),'utf8'));
const tabProps=schemaObj.properties.Tabs.items.properties;
const sectionProps=tabProps.Sections.items.properties;
if(!tabProps.Group || !tabProps.Description || !sectionProps.Icon || !sectionProps.Span || !sectionProps.Layout) fail('declarative schema missing Group/Description/Icon/Span/Layout'); else ok('declarative schema exposes visual and responsive layout features');
const dropdownSchema=sectionProps.Controls.items.oneOf.find(item=>item.properties?.Type?.const==='Dropdown');
if(!dropdownSchema?.anyOf?.some(branch=>branch.required?.includes('Options')) || !dropdownSchema?.anyOf?.some(branch=>branch.required?.includes('Values')) || !dropdownSchema?.anyOf?.some(branch=>branch.required?.includes('Source'))) fail('Dropdown schema must accept Options, Values, or Source'); else ok('Dropdown schema accepts Options, Values, or Source');
if(!hasCode(build,'Group=td.Group') || !hasCode(build,'Icon=sd.Icon') || !hasCode(build,'Span=sd.Span') || !hasCode(build,'Layout=sd.Layout')) fail('declarative runtime builder ignores new layout fields'); else ok('declarative builder forwards Group/Icon/Span/Layout');
if(!init.includes('locale:Register("en"') || !init.includes('locale:Register("ru"') || !init.includes('locale:Register("es"')) fail('built-in locale packs missing'); else ok('EN/RU/ES built-in locale packs wired');

// Lightweight lexical delimiter check. It is intentionally not a Luau parser,
// but catches the most common edit-time corruption before shipping a bundle.
function balancedDelimiters(source,file){
  const stack=[]; const opens={'(':')','[':']','{':'}'}; const closes=new Set(Object.values(opens));
  let mode='code', quote='', i=0;
  while(i<source.length){const c=source[i], n=source[i+1];
    if(mode==='line'){if(c==='\n')mode='code'; i++; continue;}
    if(mode==='block'){if(c===']'&&n===']'){mode='code';i+=2}else i++;continue;}
    if(mode==='string'){if(c==='\\'){i+=2;continue} if(c===quote){mode='code'} i++;continue;}
    if(mode==='backtick'){if(c==='\\'){i+=2;continue} if(c==='`'){mode='code'} i++;continue;}
    if(c==='-'&&n==='-'){if(source[i+2]==='['&&source[i+3]==='['){mode='block';i+=4}else{mode='line';i+=2}continue;}
    if(c==='"'||c==="'"){mode='string';quote=c;i++;continue;}
    if(c==='`'){mode='backtick';i++;continue;}
    if(opens[c])stack.push([c,i]); else if(closes.has(c)){const top=stack.pop(); if(!top||opens[top[0]]!==c)return `mismatched ${c} at ${i}`;}
    i++;
  }
  if(mode==='string'||mode==='backtick'||mode==='block')return `unterminated ${mode}`;
  if(stack.length){const [c,pos]=stack.at(-1);return `unclosed ${c} at ${pos}`;}
  return null;
}
let lexicalFailures=0;
for(const [p,s] of all){const err=balancedDelimiters(s,p); if(err){lexicalFailures++;fail(`lexical delimiter check ${p}: ${err}`)}}
if(!lexicalFailures)ok('all source modules pass lexical delimiter sanity check');
const runtimeLuaArtifacts=['tests/00-shell-smoke.lua','tests/01-full-smoke.lua','tests/02-all-features-smoke.lua','tests/03-0.11-expansion-smoke.lua','tests/04-loader-diagnostic.lua','tests/BobloUI-Full-Diagnostic.lua','tests/leak.lua','examples/basic.lua','examples/declarative.lua','examples/mobile.lua','examples/visual-showcase.lua','examples/all-features.lua','examples/0.11-showcase.lua','examples/p1-p2-showcase.lua','examples/regression-0.10.1.lua'];
let artifactLexicalFailures=0;
for(const rel of runtimeLuaArtifacts){const src=readFileSync(join(root,rel),'utf8');const err=balancedDelimiters(src,rel);if(err){artifactLexicalFailures++;fail(`lexical delimiter check ${rel}: ${err}`)}}
if(!artifactLexicalFailures)ok('runtime tests/examples pass lexical delimiter sanity check');

if(!process.exitCode) console.log('extended capability checks passed');

// Public surface completeness -------------------------------------------------
const publicInitMethods=['OpenSettings','SetTheme','SetAccent','SetThemeToken','SetHighContrast','RegisterTheme','SaveCustomTheme','DeleteCustomTheme','ReloadCustomThemes','ListCustomThemes','LoadCustomTheme','SetDefaultTheme','GetDefaultTheme','LoadDefaultTheme','SetDensity','SetScale','GetScale','ExportTheme','ImportTheme','SetLocale','SetReducedMotion','SetKeyboardNavigation','SetUISounds','SetSoundVolume','RegisterSound','PlaySound','OpenSearch','OpenCommands','AddDraggableLabel','AddDraggableButton','AddDraggableMenu','Build'];
for(const method of publicInitMethods) if(!init.includes(`function window:${method}`)) fail(`public window facade missing ${method}`);
const publicWindowMethods=['SetLocked','IsLocked','SetRememberGeometry','GetRememberGeometry','SetSidebarHidden','IsSidebarHidden','ToggleSidebar','SetSidebarWidth','GetSidebarWidth','SetSidebarResizeEnabled','SetCompact','IsCompact','SetSidebarCompacted','IsSidebarCompacted','SetResponsiveThresholds','SetSearchEnabled','SetGlobalSearch','SetSearchbarSize','SetTabSwipe','SetFont','GetFont','SetAnimations','SetAnimationEnabled','SetSize','SetPosition','GetGeometry','ResetGeometry','Minimize','Restore','ResetAll','Show','Hide','Toggle','IsVisible','SetTitle','SetIcon','SetSubtitle','SetFooterText','GetFooterText'];
for(const method of publicWindowMethods) if(!windowSrc.includes(`function Window:${method}`)) fail(`Window method missing ${method}`);
const commonControlMethods=['Reset','CopyValue','PasteValue','SetVisible','IsVisible','SetDisabled','IsDisabled','SetLoading','SetBadge','Reveal','Highlight'];
for(const method of commonControlMethods) if(!baseControl.includes(`function Base:${method}`)) fail(`common control API missing ${method}`);
if(publicInitMethods.every(m=>init.includes(`function window:${m}`)) && publicWindowMethods.every(m=>windowSrc.includes(`function Window:${m}`)) && commonControlMethods.every(m=>baseControl.includes(`function Base:${m}`))) ok('public window/control facade complete');
const allFeaturesSmoke=readFileSync(join(root,'tests/02-all-features-smoke.lua'),'utf8');
for(const needle of ['OpenSettings','SetThemeToken','SetHighContrast','SetScale','SetDensity','SetKeyboardNavigation','SetUISounds','Favorites:Add','Config:Save','Dialog:Choice','Notify:Push','AddCustom','Style="Segmented"','Span = 2','Layout = "Grid"']) if(!hasCode(allFeaturesSmoke,needle)) fail(`all-features runtime smoke missing ${needle}`);
if(!process.exitCode) console.log('release surface checks passed');
for (const [file,text] of all) {
  if(/:[A-Za-z_][A-Za-z0-9_]*\s+(?:and|or|then)\b/.test(text)) {
    fail(`invalid colon method reference used as a value in ${file}`);
  }
}
ok('no invalid colon-method references used as values');


// 0.10.1 regression guards ----------------------------------------------------
const inputSrc=readFileSync(join(root,'src/kernel/Input.lua'),'utf8');
const keybindSrc=readFileSync(join(root,'src/controls/Keybind.lua'),'utf8');
if(!hasCode(windowSrc,'local rowHeight=heightOf(first)') || !hasCode(windowSrc,'rowHeight=math.max(rowHeight,heightOf(second))')) fail('two-column row layout guard missing'); else ok('two-column row layout prevents card overlap');
if(!hasCode(tabSrc,'Icon.setColor(self._avatar,theme:Get(if selected then "Accent" else "TextSecondary"))') || !hasCode(tabSrc,'BackgroundTransparency=if selected then 0.4 elseif hover then 0.68 else 0.82')) fail('inactive sidebar icon contrast regression'); else ok('inactive sidebar icons use readable TextSecondary contrast');
if(!hasCode(dialogSrc,'Size=if full then UDim2.new(1,0,0,34)') || (!hasCode(dialogSrc,'{FullWidth=true}') && !hasCode(dialogSrc,'{FullWidth=true,Icon=choice.Icon}')) || !hasCode(dialogSrc,'ClipsDescendants=true')) fail('dialog choice/overflow regression guards missing'); else ok('Choice dialog rows and viewport overflow guards wired');
if(!inputSrc.includes('GetFocusedTextBox') || !inputSrc.includes('if self._nextCapture then') || inputSrc.includes('self._nextCapture and not processed')) fail('keybind processed-input/capture reliability fix missing'); else ok('keybind capture ignores processed flag while bindings suppress typing');
if(!keybindSrc.includes('self._janitor:Release("capture")') || !keybindSrc.includes('CaptureNextKey(function(key)')) fail('keybind capture lifecycle cleanup missing'); else ok('keybind capture lifecycle cleanup wired');
if(!hasCode(inputSrc,'Input=input') || !inputSrc.includes('matchesCapturedPointer') || !hasCode(inputSrc,'return input==captured')) fail('drag capture is not scoped to the initiating pointer'); else ok('drag capture ignores unrelated touch pointers');
if(!motionSrc.includes('function Motion:Cancel') || !hasCode(windowLayoutSrc,'self.Motion:Cancel(self._root)')) fail('window drag does not cancel competing position tween'); else ok('window drag cancels competing position tween');
if(!windowLayoutSrc.includes('function WindowLayout:_clampDragPosition') || !hasCode(windowLayoutSrc,'self._root.Position=self:_clampDragPosition(proposed)')) fail('window drag safe-area clamp missing'); else ok('window drag remains inside the safe area');
// 0.10.3 regression guards: UIScale must not be applied twice to logical layout sizes.
if(!hasCode(windowSrc,'self._sectionHost.AbsoluteSize.X/scale') || !hasCode(windowSrc,'section._root.AbsoluteSize.Y or scale')) fail('scale-aware section layout guard missing'); else ok('section layout converts AbsoluteSize back to logical pixels');
if(!hasCode(tabSrc,'local edgeInset=1') || !hasCode(tabSrc,'local layoutWidth=math.max(1,available-edgeInset*2)') || !hasCode(tabSrc,'math.max(0,y-gap+edgeInset)')) fail('SectionHost/card border inset can be erased during relayout'); else ok('SectionHost layout preserves padding and complete card borders');
if(!hasCode(windowSrc,'local startSize = self._root.AbsoluteSize/scale') || !hasCode(windowSrc,'(move.Position - startPosition)/scale')) fail('scale-aware resize math guard missing'); else ok('resize math is scale-aware');
if(!hasCode(windowChromeSrc,'self._headerCorner=New("UICorner"') || !hasCode(windowChromeSrc,'self._footerCorner=New("UICorner"') || !windowCoreSrc.includes('_backgroundImageCorner') || !windowCoreSrc.includes('_flashCorner') || !windowLayoutSrc.includes('function WindowLayout:_applyCornerRadius')) fail('visible window corner radius surfaces missing'); else ok('window radius reaches root/header/footer/image/flash surfaces');
if(!windowSrc.includes('ClipsDescendants = true') || !windowSrc.includes('Name = "SectionHost"')) fail('section host clipping guard missing'); else ok('section host clipping guard wired');
if(windowCoreSrc.includes('_rootHalo') || darkThemeSrc.includes('Shadow') || lightThemeSrc.includes('Shadow')) fail('window shadow halo was reintroduced'); else ok('window shell is shadow-free');
if(!hasCode(sectionSrc,'StrokeToken="Border"') || !hasCode(sectionSrc,'StrokeTransparency=0.3') || !hasCode(sectionSrc,'Sheen=false') || !readFileSync(join(root,'src/primitives/Surface.lua'),'utf8').includes('LineJoinMode = Enum.LineJoinMode.Round')) fail('uniform container border contract missing'); else ok('containers use uniform round borders without fake top sheen');


// 0.11 expansion guards ------------------------------------------------------
const progressSrc=readFileSync(join(root,'src/controls/Progress.lua'),'utf8');
const codeSrc=readFileSync(join(root,'src/controls/Code.lua'),'utf8');
const imageSrc=readFileSync(join(root,'src/controls/Image.lua'),'utf8');
const loadingSrc=readFileSync(join(root,'src/services/Loading.lua'),'utf8');
const hudSrc=readFileSync(join(root,'src/services/HUD.lua'),'utf8');
const cursorSrc=readFileSync(join(root,'src/services/Cursor.lua'),'utf8');
const rowSrc=readFileSync(join(root,'src/shell/Row.lua'),'utf8');
const tabBoxSrc=readFileSync(join(root,'src/shell/TabBox.lua'),'utf8');
for(const method of ['AddProgress','AddCode','AddImage']) if(!sectionSrc.includes(`function Section:${method}`) || !windowSrc.includes(`function Tab:${method}`)) fail(`0.11 constructor missing ${method}`);
if(!progressSrc.includes('SetIndeterminate') || !codeSrc.includes('CopyCode') || !imageSrc.includes('SetImage')) fail('new presentation controls incomplete'); else ok('Progress/Code/Image controls wired');
if(!hasCode(baseControl,'self.Icon=options.Icon') || !baseControl.includes('function Base:SetIcon')) fail('control icon API missing'); else ok('control icons wired');
if(!hasCode(sectionSrc,'Icon=options.Icon or "layers"') || !sectionSrc.includes('function Section:SetIcon') || !sectionSrc.includes('Name = "SectionHeader"') || !hasCode(build,'local SECTION_KEYS={Id=true,Title=true,Description=true,Icon=true')) fail('section visual identity API missing'); else ok('section icon + structured header wired');
if(!windowSrc.includes('Name = "IconTile"') || !windowSrc.includes('Name = "PageIconTile"') || !iconSrc.includes('Draw["sliders-horizontal"]')) fail('expanded icon-led visual language missing'); else ok('expanded icon-led visual language wired');
if(!dropdownSrc.includes('LockedReason') || !dropdownSrc.includes('RefreshSource') || !hasCode(dropdownSrc,'Description=option.Description or option.Desc')) fail('advanced dropdown/data source API incomplete'); else ok('advanced dropdown + data sources wired');
if(!init.includes('BobloUI.Sources.Players') || !init.includes('function BobloUI.Source')) fail('public data source factory missing'); else ok('player/generic data sources wired');
const textFieldSrc=readFileSync(join(root,'src/controls/TextField.lua'),'utf8');
if(!textFieldSrc.includes('self.Multiline') || !textFieldSrc.includes('self.Height')) fail('multiline textarea sizing missing'); else ok('textarea input wired');
if(!windowSrc.includes('function Window:AddTopbarButton') || !windowSrc.includes('function Window:AddTopbarTag')) fail('custom topbar API missing'); else ok('topbar buttons/tags wired');
if(!loadingSrc.includes('function Loading:Show') || !init.includes('function window:ShowLoading')) fail('loading/boot screen missing'); else ok('loading screen wired');
if(!rowSrc.includes('function Row:AddButton') || !sectionSrc.includes('function Section:AddRow')) fail('HStack/Row API missing'); else ok('row/HStack layout wired');
if(!tabBoxSrc.includes('function TabBox:AddTab') || !sectionSrc.includes('function Section:AddTabBox')) fail('sub-tabs/TabBox API missing'); else ok('TabBox sub-tabs wired');
if(!windowSrc.includes('LockedReason') || !windowSrc.includes('function Tab:SetLocked')) fail('locked tab API missing'); else ok('locked tabs wired');
const sliderSrc=readFileSync(join(root,'src/controls/Slider.lua'),'utf8');
if(!sliderSrc.includes('FloatingValue') || !sliderSrc.includes('IconFrom') || !sliderSrc.includes('ValueInput')) fail('slider enhancements missing'); else ok('slider tooltip/input/end-icons wired');
const toggleSrc=readFileSync(join(root,'src/controls/Toggle.lua'),'utf8');
if(!hasCode(toggleSrc,'Style=="Checkbox"')) fail('checkbox toggle style missing'); else ok('checkbox toggle style wired');
if(!windowSrc.includes('function Window:SetRestoreButton') || !windowSrc.includes('Draggable')) fail('custom restore button API incomplete'); else ok('custom restore button wired');
if(!init.includes('"FooterText"') || !windowChromeSrc.includes('function WindowChrome:SetFooterText') || !windowChromeSrc.includes('function WindowChrome:GetFooterText') || !hasCode(windowLayoutSrc,'Parent=self._footer') || windowChromeSrc.includes('Drag corner to resize')) fail('footer text/resize affordance contract incomplete'); else ok('footer text API + contained resize affordance wired');
if(!windowSrc.includes('function Window:SetWindowOpacity') || !windowSrc.includes('function Window:SetBackgroundImage')) fail('window opacity/background image API incomplete'); else ok('window opacity/background image wired');
if(!windowSrc.includes('function Window:SetTabTransition') || !windowSrc.includes('_tabTransition')) fail('tab transition API missing'); else ok('tab transitions wired');
if(!notifySrc.includes('function Notify:SetPosition')) fail('notification positioning API missing'); else ok('notification position wired');
if(!hudSrc.includes('SetWatermark') || !hudSrc.includes('SetKeybindHUD') || !init.includes('SetKeybindHUD')) fail('HUD services missing'); else ok('watermark/keybind HUD wired');
if(!cursorSrc.includes('MouseIconEnabled') || !init.includes('SetCustomCursor')) fail('custom cursor API missing'); else ok('custom cursor wired');

if(!windowSrc.includes('function Window:SetWindowAnimation') || !windowSrc.includes('_windowAnimation')) fail('window open/close animation API missing'); else ok('window open/close animation wired');
if(windowSrc.includes('if options.BackgroundImage then self:SetBackgroundImage(options.BackgroundImage')) fail('Window:_build references out-of-scope options.BackgroundImage'); else ok('Window background-image options captured before _build');
if(!hasCode(windowSrc,'_backgroundImageSource = options.BackgroundImage') || !hasCode(windowSrc,'if self._backgroundImageSource then self:SetBackgroundImage')) fail('Window background-image option capture missing'); else ok('Window background-image option capture wired');

// 0.11.2 Rayfield-style visibility/reopen regression guards.
if(!init.includes('"ToggleUIKeybind"') || !init.includes('"ShowText"') || !init.includes('options.ToggleUIKeybind')) fail('Rayfield-style ShowText/ToggleUIKeybind window options missing'); else ok('ShowText + ToggleUIKeybind compatibility wired');
if(!windowSrc.includes('else "Always"') || !windowSrc.includes('function Window:_shouldShowRestoreButton')) fail('cross-device default restore prompt missing'); else ok('restore prompt defaults to all devices');
if(!hasCode(windowSrc,'b.Visible=(not self._visible) and self:_shouldShowRestoreButton()')) fail('restore prompt can appear while window is visible'); else ok('restore prompt only appears while window is hidden');
if(!windowSrc.includes('Parent = self.Layers.Toast') || !windowSrc.includes('ZIndex = 1000')) fail('restore prompt is not on the top UI layer'); else ok('restore prompt renders on top layer');
if(!windowSrc.includes('_showText = options.ShowText or "Show BobloUI"')) fail('default Show BobloUI label missing'); else ok('default restore label is Show BobloUI');
if(!hasCode(hudSrc,'if spec==false or spec==nil then')) fail('watermark opt-out/default guard missing'); else ok('watermark remains explicit opt-in');

const windowThemeBoundary = windowChromeSrc.match(/local function drawThemeIcon[\s\S]*?function WindowChrome:_buildHeader/);
if(!windowThemeBoundary || /\nend\nend\n\nfunction WindowChrome:_buildHeader/.test(windowThemeBoundary[0])) fail('theme icon function has an extra end before header build'); else ok('theme icon function boundary has no extra end');

// 0.11.5 hardening contract --------------------------------------------------
const storeSrc=readFileSync(join(root,'src/kernel/Store.lua'),'utf8');
const registrySrc=readFileSync(join(root,'src/kernel/Registry.lua'),'utf8');
const searchSrc=readFileSync(join(root,'src/services/Search.lua'),'utf8');
const runtimeManifestSrc=readFileSync(join(root,'src/runtime/RuntimeManifest.lua'),'utf8');
const ciSrc=readFileSync(join(root,'.github/workflows/ci.yml'),'utf8');
const packageSrc=readFileSync(join(root,'package.json'),'utf8');
const controlSources=all.filter(([path])=>path.includes('/src/controls/')).map(([,source])=>source).join('\n');

for(const needle of ['serviceValue','_existingEnvelope','missing config migration','autoload update failed']) {
  if(!configSrc.includes(needle)) fail(`Config hardening missing ${needle}`);
}
if(!hasCode(configSrc,'if not self._window.Registry:Has(id) then values[id]=rawValue')) fail('Config Save does not preserve unknown existing values');
for(const needle of ['_queue','_drain','_activeChain','_snapshots','_trackers','function Store:Watch(id, fn, owner)','function Store:WatchMany(ids, fn, owner)']) {
  if(!storeSrc.includes(needle)) fail(`Store hardening missing ${needle}`);
}
if(!storeSrc.includes('seen[a]') || !storeSrc.includes('State cascade exceeded')) fail('Store equality/cascade guards incomplete');
if(!baseControl.includes('dependency tracked 0 State:Get calls')) fail('zero-dependency tracking warning missing');
if(!registrySrc.includes('function Registry:AssertAvailable') || !baseControl.includes('Registry:AssertAvailable(options.Id')) fail('duplicate Id preflight missing');
if(/CanvasGroup|GroupTransparency/.test(controlSources)) fail('control roots still use CanvasGroup rendering');
if(/GetPropertyChangedSignal\("AbsoluteSize"\)/.test(controlSources) || !sectionSrc.includes('_updateAdaptiveControls')) fail('AbsoluteSize delegation is not section-owned');
for(const needle of ['_index','_byKey','function Search:Reindex','function Search:QueryDebounced','_registry.Updated']) {
  if(!searchSrc.includes(needle)) fail(`Search indexing missing ${needle}`);
}
if(!runtimeManifestSrc.includes('["Common"]') || !runtimeManifestSrc.includes('["Components"]') || !validateSrc.includes('Manifest.Common')) fail('RuntimeManifest Common split missing');
for(const file of ['src/shell/Window.lua','src/shell/Tab.lua','src/shell/WindowChrome.lua','src/shell/WindowLayout.lua']) {
  if(!existsSync(join(root,file))) fail(`Window split missing ${file}`);
}
if(/`\$/.test(baseControl)) fail('Base interpolation still contains a literal $ prefix');
if(!hasCode(init,'janitor:Add(search)') || !hasCode(init,'janitor:Add(commands)')) fail('Search/Commands janitor ownership missing');
for(const needle of ['python3 luaucheck.py','python3 harness.py tests/store.spec.lua']) {
  if(!packageSrc.includes(needle)) fail(`package test pipeline missing ${needle}`);
}
if(!ciSrc.includes('stylua-action') || !ciSrc.includes('--no-ignore-vcs --check src') || !ciSrc.includes('src/runtime/RuntimeManifest.lua') || !ciSrc.includes('src/schema/Manifest.lua') || !ciSrc.includes('lua5.3')) fail('CI syntax/format runtime prerequisites incomplete');
if(!process.exitCode) ok('0.11.5 P0/P1/P2 hardening contract complete');

// Obsidian gap P1/P2 completion contract ------------------------------------
const dependencySrc=readFileSync(join(root,'src/runtime/Dependency.lua'),'utf8');
const overlaysSrc=readFileSync(join(root,'src/services/Overlays.lua'),'utf8');
const themeManagerSrc=readFileSync(join(root,'src/services/ThemeManager.lua'),'utf8');
const passthroughSrc=readFileSync(join(root,'src/controls/Passthrough.lua'),'utf8');
const viewportSrc=readFileSync(join(root,'src/controls/Viewport.lua'),'utf8');
const videoSrc=readFileSync(join(root,'src/controls/Video.lua'),'utf8');
const buttonSrc=readFileSync(join(root,'src/controls/Button.lua'),'utf8');

for(const method of ['AddFooterButton','RemoveFooterButton','SetButtonDisabled','SetButtonOrder','SetTitle','SetDescription','Dismiss','IsOpen','Await']) {
  if(!dialogSrc.includes(`function handle:${method}`)) fail(`Dialog v2 handle missing ${method}`);
}
for(const needle of ['WaitTime','OutsideClickDismiss','AutoDismiss','DialogSection.new']) if(!dialogSrc.includes(needle)) fail(`Dialog v2 missing ${needle}`);
if(dialogSrc.includes('DialogSection.new') && dialogSrc.includes('function handle:AddFooterButton')) ok('Dialog v2 dynamic footer, dismiss policy and full controls wired');

for(const method of ['AddLabel','AddButton','AddMenu']) if(!overlaysSrc.includes(`function Overlays:${method}`)) fail(`public draggable overlay missing ${method}`);
for(const method of ['SetVisible','SetPosition','GetInstance','Destroy']) if(!overlaysSrc.includes(`function handle:${method}`)) fail(`overlay handle missing ${method}`);
if(!hasCode(init,'window.Overlays=overlays') || !init.includes('function window:AddDraggableMenu')) fail('overlay service facade missing'); else ok('public draggable overlays wired');

for(const needle of ['Modifiers','ExactModifiers','ModeHandler']) if(!inputSrc.includes(needle)) fail(`Input key chord support missing ${needle}`);
for(const needle of ['Whitelist','Blacklist','ModifierWhitelist','BlacklistModifiers','WaitForCallback','ChangedCallback','CustomModes','AttachTo','SyncToggle','MobileText','function Keybind:SetModifiers','function Keybind:Attach','function Keybind:Trigger']) if(!keybindSrc.includes(needle)) fail(`Keybind v2 missing ${needle}`);
if(!hudSrc.includes('h:Trigger()') || !hudSrc.includes('h.Mobile ~= false')) fail('mobile keybind HUD actions missing'); else ok('Keybind v2 modifiers, modes, attachment and mobile actions wired');

for(const [name,source] of [['Section',sectionSrc],['Row',rowSrc],['TabBox',tabBoxSrc]]) {
  if(!source.includes('Dependency.Bind') || !source.includes('VisibleWhen') || !source.includes('EnabledWhen') || !source.includes('_applyContainerState')) fail(`${name} reactive visibility/enabled contract incomplete`);
}
if(!dependencySrc.includes('function Dependency.Bind') || !dependencySrc.includes('WatchMany') || !dependencySrc.includes('Track')) fail('shared container dependency tracker incomplete'); else ok('Section/Row/TabBox reactive containers wired');

for(const [typeName,source] of [['Passthrough',passthroughSrc],['Viewport',viewportSrc],['Video',videoSrc]]) {
  if(!manifest.components[typeName] || !source.includes(`function ${typeName}.new`)) fail(`${typeName} control/manifest missing`);
  const method=manifest.components[typeName]?.method;
  if(method && (!sectionSrc.includes(`function Section:${method}`) || !tabSrc.includes(`function Tab:${method}`) || !rowSrc.includes(`function Row:${method}`) || !tabBoxSrc.includes(`function SubTab:${method}`) || !dialogSectionSrc.includes(`function DialogSection:${method}`))) fail(`${typeName} constructor is not available in every control container`);
}
if(passthroughSrc.includes('GetContentInstance') && viewportSrc.includes('function Viewport:Focus') && videoSrc.includes('function Video:Play')) ok('Passthrough, Viewport and Video controls wired');

for(const method of ['SaveCustomTheme','DeleteCustomTheme','ReloadCustomThemes','ListCustomThemes','Load','ApplyTheme','GetCustomTheme','SetDefault','SaveDefault','GetDefault','LoadDefault','SetFolder']) if(!themeManagerSrc.includes(`function ThemeManager:${method}`)) fail(`ThemeManager missing ${method}`);
if(!themeManagerSrc.includes('/themes') || !themeManagerSrc.includes('default.txt') || !hasCode(init,'window.ThemeManager=themeManager') || !init.includes('function window:SetThemeFolder')) fail('persisted custom theme library/default integration missing'); else ok('persisted custom theme library and default wired');

for(const method of ['SetSidebarWidth','GetSidebarWidth','SetSidebarResizeEnabled','SetCompact','IsCompact','SetFont','GetFont']) if(!windowLayoutSrc.includes(`function WindowLayout:${method}`)) fail(`Window customization missing ${method}`);
const typographySrc=readFileSync(join(root,'src/runtime/Typography.lua'),'utf8');
for(const needle of ['Figtree-Regular.ttf','Figtree-Medium.ttf','Figtree-Bold.ttf','Figtree-ExtraBold.ttf','function Typography.Prepare','Font.new(familyAsset','BuilderSans fallback']) if(!typographySrc.includes(needle)) fail(`Figtree typography integration missing ${needle}`);
if(!createSrc.includes('key == "Font" and typeof(value) == "Font"') || !windowLayoutSrc.includes('typeof(resolved) ~= "Font"') || !dialogSrc.includes('GetTextBoundsAsync')) fail('FontFace compatibility path incomplete'); else ok('Figtree default and legacy Enum.Font override paths wired');
for(const method of ['SetAnimations','SetAnimationEnabled']) if(!windowChromeSrc.includes(`function WindowChrome:${method}`)) fail(`granular animation API missing ${method}`);
if(!motionSrc.includes('function Motion:SetCategory') || !motionSrc.includes('function Motion:IsEnabled') || !windowChromeSrc.includes('SetCategory("Window"') || !windowChromeSrc.includes('SetCategory("Tabs"') || !windowChromeSrc.includes('SetCategory("Controls"')) fail('animation categories are not independent');
if(!windowLayoutSrc.includes('SidebarResizeGrip') || !hasCode(windowLayoutSrc,'SidebarWidth=self._sidebarWidth') || !hasCode(windowLayoutSrc,'Compact=self:IsCompact()')) fail('sidebar/compact geometry persistence missing'); else ok('sidebar width/drag, compact, font and independent animation APIs wired');

for(const method of ['SetCaption','SetHeight','SetTint','SetTransparency','SetRect','SetScaleType']) if(!imageSrc.includes(`function Image:${method}`)) fail(`Image v2 missing ${method}`);
for(const needle of ['Icon','Steps','DialogSection.new','function h:SetSteps','function h:SetMessage','function h:SetDescription','function h:SetCurrentStep','function h:SetTotalSteps','function h:SetLoadingIcon','function h:SetLoadingIconTweenTime','function h:SetLoadingIconColor','function h:ShowSidebarPage','function h:ShowErrorPage','function h:SetErrorMessage','function h:SetErrorButtons','function h:Continue']) if(!loadingSrc.includes(needle)) fail(`Loading v2 missing ${needle}`);
for(const needle of ['BigImage','BigIcon','Persist','Steps','SoundId','ImageScaleType','AccentColor','TitleColor','ContentColor','SoundOptions','function item:ChangeTitle','function item:ChangeDescription','function item:ChangeStep','function item:Destroy']) if(!notifySrc.includes(needle)) fail(`Notification v2 missing ${needle}`);
if(imageSrc.includes('SetRect') && loadingSrc.includes('DialogSection.new') && notifySrc.includes('BigImage')) ok('richer Image, Loading and Notifications wired');

for(const needle of ['DoubleClick','DoubleClickWindow','SubButtons','function Button:AddAction','function Button:AddKeybind']) if(!buttonSrc.includes(needle)) fail(`Button v2 missing ${needle}`);
for(const needle of ['Values','MaxVisibleRows','DragSelect','FormatDisplayValue','FormatListValue','DisabledValues','ValueImages','function Dropdown:SetValues','function Dropdown:AddValues','function Dropdown:SetDisabledValues','function Dropdown:AddDisabledValues','function Dropdown:SetValueImage','function Dropdown:SetValueImages','function Dropdown:AddValueImages','function Dropdown:SetDragSelect','function Dropdown:GetActiveValues','function Dropdown:SetMaxVisibleRows','function Dropdown:SetFormatters']) if(!dropdownSrc.includes(needle)) fail(`Dropdown v2 missing ${needle}`);
if(buttonSrc.includes('function Button:AddAction') && dropdownSrc.includes('function Dropdown:SetFormatters')) ok('Button and Dropdown P2 interaction APIs wired');

const paragraphSrc=readFileSync(join(root,'src/controls/Paragraph.lua'),'utf8');
const dividerSrc=readFileSync(join(root,'src/controls/Divider.lua'),'utf8');
for(const needle of ['AllowEmpty','EmptyReset','ClearTextOnBlur','ClearTextOnFocus','VerifyValue','Finished','function TextField:SetAllowEmpty']) if(!textFieldSrc.includes(needle)) fail(`Input P3 missing ${needle}`);
if(!hasCode(textFieldSrc,'if options.AllowEmpty~=nil then options.AllowEmpty~=false else not self.Numeric') || !hasCode(textFieldSrc,'self.Numeric and 0 or default')) fail('Input P3 defaults break numeric Clear compatibility'); else ok('Input numeric Clear keeps zero compatibility');
for(const needle of ['Prefix','Compact','HideMax','AllowRightClickInput','FormatDisplayValue','function Slider:SetPrefix','function Slider:SetSuffix']) if(!sliderSrc.includes(needle)) fail(`Slider P3 missing ${needle}`);
for(const needle of ['RichText','DoesWrap','function Paragraph:SetRichText','function Paragraph:SetWrap','function Paragraph:SetSize']) if(!paragraphSrc.includes(needle)) fail(`Paragraph P3 missing ${needle}`);
for(const needle of ['MarginTop','MarginBottom','function Divider:SetMargins']) if(!dividerSrc.includes(needle)) fail(`Divider P3 missing ${needle}`);
for(const needle of ['MultiValueMode','ReturnMap','function Dropdown:_selectedList','function Dropdown:_selectionCount']) if(!dropdownSrc.includes(needle)) fail(`Dropdown P3 missing ${needle}`);
for(const needle of ['DisableSearch','SearchbarSize','GlobalSearch','ShowMobileButtons','MobileButtonsSide','EnableCompacting','DisableCompactingSnap','SidebarCompacted','MinContainerWidth','MinSidebarWidth','SidebarCompactWidth','SidebarCollapseThreshold','CompactWidthActivation','TabTransitionTime','TabSwipeOffset','TabSwipeFrom']) if(!init.includes(`"${needle}"`) || !windowSrc.includes(needle)) fail(`Window P3 option missing ${needle}`);
for(const component of ['Input','Slider','Paragraph','Divider','Dropdown']) {
  const options=manifest.components[component]?.options||{};
  if(component==='Input' && !options.AllowEmpty) fail('generated Input manifest omits P3 options');
  if(component==='Slider' && !options.AllowRightClickInput) fail('generated Slider manifest omits P3 options');
  if(component==='Paragraph' && !options.RichText) fail('generated Paragraph manifest omits P3 options');
  if(component==='Divider' && !options.MarginTop) fail('generated Divider manifest omits P3 options');
  if(component==='Dropdown' && !options.MultiValueMode) fail('generated Dropdown manifest omits P3 options');
}
if(textFieldSrc.includes('ClearTextOnBlur') && dropdownSrc.includes('MultiValueMode') && windowSrc.includes('SetResponsiveThresholds')) ok('Obsidian gap P3 controls and window tuning wired');
if(!configSrc.includes('geometry.SidebarCompacted') || !configSrc.includes('SetSidebarCompacted')) fail('P3 sidebar compact state is not persisted'); else ok('P3 sidebar compact state persists with geometry');

if(!process.exitCode) ok('Obsidian gap P1/P2/P3 completion contract complete');
