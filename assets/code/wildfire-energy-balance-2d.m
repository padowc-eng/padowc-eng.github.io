function wildfire_energy_balance_2d
% wildfire_energy_balance_2d
% 2D cell-based wood combustion and wildfire energy-balance demonstration.
% Run: wildfire_energy_balance_2d
%
% Each cell has dry fine/coarse fuel, water, heat capacity and temperature.
% The fuel produces heat after it is hot and dry enough to ignite.
% Combustion energy is split between local heating, four neighboring
% cells, and loss to the atmosphere. Neighboring cells also exchange
% sensible heat. Energy needed to evaporate water slows down heating.
%
% This is an illustrative teaching model, NOT a wildfire prediction tool.
% Burn rates, coupling fractions, and vegetation properties are estimated.
% No smoke, ember spotting, true 3D buoyancy, or detailed wood kinetics.

p.nx = 86;                         % cells horizontally
p.ny = 57;                         % cells vertically
p.dx = 2;                          % meters per cell (top-down)
p.dt = 0.12;                       % simulation timestep, seconds
p.stepsPerFrame = 40;               % timesteps per animation update
p.maxTime = 5600;                  % seconds
p.seed = 17;
p.density = 0.84;                  % target forest coverage, 0-1
p.treeFraction = 0.37;             % trees among occupied locations
p.moisture = 0.15;                 % kg of water / kg of dry fuel
p.relativeHumidity = 0.40;         % air relative humidity, 0-1
p.ambientC = 22;                   % degrees C
p.wind = 2.5;                      % m/s, positive toward right
p.windVertical = 0.25;             % positive down the screen
p.rockFraction = 0.015;
p.firebreak = false;

% Simplified energy parameters. These are not calibrated field constants.
p.heatLocalFraction = 0.17;        % heat from fire returned to its own cell
p.heatNeighborFraction = 0.39;     % heat from fire sent to 4 neighbors
% The remainder of combustion heat goes to the surroundings/atmosphere.
p.windWeight = 0.36;               % strength of wind directional bias
p.G = 85;                         % effective sensible exchange W/K per face
p.h = 8;                          % ambient convection W/(m^2 K)
p.emissivity = 0.76;
p.sigma = 5.670374419e-8;         % Stefan-Boltzmann constant
p.airCapacity = 3.5e4;             % effective air/background capacity J/K/cell
p.rockCapacity = 1.0e5;            % extra J/K for rocky cell
p.cpDry = 1650;                    % dry vegetation J/(kg K)
p.cpWater = 4180;                  % water J/(kg K)
p.latent = 2.26e6;                 % water evaporation J/kg
p.boil = 373.15;                   % simplified evaporation threshold K
p.dryingRate = .0015;              % simplified below-boiling evaporation, 1/s
p.burnTempFloor = 460;             % burning needs a hot enough cell K
p.displayFluxMax = 150;            % upper scale for incoming heat, kW/m^2

running = false;
selected = [round(p.ny/2),round(p.nx/5)]; % row, column
s = newForest(p);
s = igniteNear(s,selected(1),selected(2));
histT = 0;
histBurn = 0;
histPower = 0;

fig = figure('Name','Wildfire - cell energy balance (2D)', ...
    'NumberTitle','off','Color',[.96 .97 .97], ...
    'Position',[70 65 1440 840],'Resize','off', ...
    'CloseRequestFcn',@closeWindow);
axMap = axes('Parent',fig,'Position',[.055 .31 .49 .61]);
mapImage = image(axMap,zeros(p.ny,p.nx,3));
axis(axMap,'image'); axis(axMap,'tight');
set(axMap,'YDir','reverse','XTick',[],'YTick',[]);
title(axMap,'Forest map: click a fuel cell to ignite it');
set(mapImage,'ButtonDownFcn',@clickMap);
hold(axMap,'on');
selMarker = plot(axMap,selected(2),selected(1),'wo', ...
    'MarkerSize',11,'LineWidth',1.5,'HitTest','off');
hold(axMap,'off');

axFlux = axes('Parent',fig,'Position',[.62 .59 .27 .32]);
fluxImage = imagesc(axFlux,zeros(p.ny,p.nx));
axis(axFlux,'image'); axis(axFlux,'tight');
set(axFlux,'YDir','reverse','XTick',[],'YTick',[]);
colormap(axFlux,hot(256));
caxis(axFlux,[0 p.displayFluxMax]);
cb = colorbar(axFlux);
ylabel(cb,'kW/m^2');
title(axFlux,'Incoming neighboring heat flux');

axHistory = axes('Parent',fig,'Position',[.62 .31 .31 .19]);
yyaxis(axHistory,'left');
lineBurn = plot(axHistory,0,0,'Color',[.15 .45 .22],'LineWidth',1.8);
ylabel(axHistory,'Fuel consumed (%)'); ylim(axHistory,[0 100]);
yyaxis(axHistory,'right');
linePower = plot(axHistory,0,0,'Color',[.80 .25 .10],'LineWidth',1.6);
ylabel(axHistory,'Heat release (MW)');
xlabel(axHistory,'Simulated time (s)');
title(axHistory,'Fuel consumption and energy release');
grid(axHistory,'on');

statusText = uicontrol(fig,'Style','text','Units','normalized', ...
    'Position',[.60 .51 .36 .06],'BackgroundColor',get(fig,'Color'), ...
    'HorizontalAlignment','left','FontSize',10,'String','');
legendText = uicontrol(fig,'Style','text','Units','normalized', ...
    'Position',[.055 .259 .50 .035], 'BackgroundColor',get(fig,'Color'), ...
    'HorizontalAlignment','left','FontSize',10, ...
    'String','Green: fuel  |  Yellow: warm  |  Orange: burning  |  Dark: burned  |  Gray: rock');

sliders = struct();
addSlider('density','Vegetation cover',.035,.15,.20,.94,p.density);
addSlider('moisture','Wood wetness',.23,.15,0,.70,p.moisture);
addSlider('relativeHumidity','Air humidity',.425,.15,0,1,p.relativeHumidity);
addSlider('wind','Wind right (m/s)',.62,.15,-6,9,p.wind);
addSlider('ambientC','Air temp (C)',.815,.15,-5,48,p.ambientC);

btnRun = uicontrol(fig,'Style','pushbutton','Units','normalized', ...
    'Position',[.07 .045 .16 .065],'FontSize',11,'String','Start / Pause', ...
    'Callback',@toggleRunning);
uicontrol(fig,'Style','pushbutton','Units','normalized', ...
    'Position',[.25 .045 .16 .065],'FontSize',11,'String','New random forest', ...
    'Callback',@regenerate);
uicontrol(fig,'Style','pushbutton','Units','normalized', ...
    'Position',[.43 .045 .16 .065],'FontSize',11,'String','Reset same forest', ...
    'Callback',@resetSame);
uicontrol(fig,'Style','pushbutton','Units','normalized', ...
    'Position',[.61 .045 .11 .065],'FontSize',11,'String','Step 1 s', ...
    'Callback',@stepOnce);
uicontrol(fig,'Style','pushbutton','Units','normalized', ...
    'Position',[.735 .045 .115 .065],'FontSize',11,'String','Save data', ...
    'Callback',@exportData);
firebreakBox = uicontrol(fig,'Style','checkbox','Units','normalized', ...
    'Position',[.86 .060 .13 .035],'FontSize',10, ...
    'BackgroundColor',get(fig,'Color'),'String','Add a firebreak', ...
    'Value',double(p.firebreak));

uicontrol(fig,'Style','text','Units','normalized', ...
    'Position',[.07 .012 .85 .024],'FontSize',9, ...
    'BackgroundColor',get(fig,'Color'), ...
    'String','Move sliders, then click New random forest to apply. Click a vegetation cell to ignite it during the run.');
render();

    function addSlider(field,label,x,y,lo,hi,value)
        caption = uicontrol(fig,'Style','text','Units','normalized', ...
            'Position',[x y+.045 .17 .035], ...
            'BackgroundColor',get(fig,'Color'), ...
            'HorizontalAlignment','left','FontSize',9);
        slider = uicontrol(fig,'Style','slider','Units','normalized', ...
            'Position',[x y .17 .032],'Min',lo,'Max',hi,'Value',value, ...
            'Callback',@(~,~) updateLabel());
        sliders.(field) = slider;
        updateLabel();
        function updateLabel()
            v = get(slider,'Value');
            if strcmp(field,'density') || strcmp(field,'moisture') || strcmp(field,'relativeHumidity')
                set(caption,'String',sprintf('%s: %.0f%%',label,100*v));
            else
                set(caption,'String',sprintf('%s: %.1f',label,v));
            end
        end
    end

    function applyControls()
        p.density = get(sliders.density,'Value');
        p.moisture = get(sliders.moisture,'Value');
        p.relativeHumidity = get(sliders.relativeHumidity,'Value');
        p.wind = get(sliders.wind,'Value');
        p.ambientC = get(sliders.ambientC,'Value');
        p.firebreak = logical(get(firebreakBox,'Value'));
    end

    function initializeSimulation()
        running = false;
        s = newForest(p);
        selected = [round(p.ny/2),round(p.nx/5)];
        s = igniteNear(s,selected(1),selected(2));
        histT = 0; histBurn = 0; histPower = 0;
        render();
    end

    function regenerate(~,~)
        running = false;
        applyControls();
        p.seed = p.seed + 1;
        initializeSimulation();
    end

    function resetSame(~,~)
        running = false;
        % Reuse same random seed and same controls currently in p.
        initializeSimulation();
    end

    function toggleRunning(~,~)
        if running
            running = false;
            return;
        end
        running = true;
        while running && isgraphics(fig) && s.time < p.maxTime
            for k = 1:p.stepsPerFrame
                s = advance(s,p);
                if s.time >= p.maxTime, break; end
            end
            addHistory();
            render();
            drawnow;          % allows buttons/sliders to respond
        end
        running = false;
    end

    function stepOnce(~,~)
        if running, return; end
        for k=1:ceil(1/p.dt)
            if s.time >= p.maxTime, break; end
            s = advance(s,p);
        end
        addHistory();
        render();
        drawnow;
    end

    function exportData(~,~)
        [fname,folder] = uiputfile('wildfire_results.mat','Save wildfire results');
        if isequal(fname,0), return; end
        result = struct('parameters',p,'forestState',s, ...
            'time_s',histT(:),'fuelConsumed_percent',histBurn(:), ...
            'heatRelease_MW',histPower(:));
        save(fullfile(folder,fname),'result');
    end

    function clickMap(~,~)
        cp = get(axMap,'CurrentPoint');
        x = round(cp(1,1)); y = round(cp(1,2));
        if x<1 || x>p.nx || y<1 || y>p.ny, return; end
        selected = [y x];
        if s.type(y,x)>=1 && s.type(y,x)<=3
            s = igniteNear(s,y,x);
        end
        render();
    end

    function addHistory()
        histT(end+1) = s.time;
        histBurn(end+1) = 100*(1-sum(s.fine(:)+s.coarse(:)) / s.initialFuel);
        histPower(end+1) = sum(s.power(:))/1e6;
    end

    function render()
        if ~isgraphics(fig), return; end
        set(mapImage,'CData',forestRGB(s));
        set(selMarker,'XData',selected(2),'YData',selected(1));
        set(fluxImage,'CData',s.incoming/(p.dx^2)/1000);
        set(axFlux,'CLim',[0 p.displayFluxMax]);
        set(lineBurn,'XData',histT,'YData',histBurn);
        set(linePower,'XData',histT,'YData',histPower);
        if numel(histT)>1
            set(axHistory,'XLim',[0 max(5,histT(end))]);
        end
        yyaxis(axHistory,'right');
        ylim(axHistory,[0 max(1.0,max(histPower)*1.25)]);
        yyaxis(axHistory,'left');
        yy = selected(1); xx = selected(2);
        remaining = s.fine(yy,xx)+s.coarse(yy,xx);
        sprintfText = sprintf(['Time: %.1f s   |   Consumed: %.1f%%   |   Active: %d cells\n' ...
            'Selected: %s at (%d,%d)   |   T: %.0f C   |   Fuel: %.1f kg   |   Water: %.1f kg'], ...
            s.time,100*(1-sum(s.fine(:)+s.coarse(:))/s.initialFuel), ...
            nnz(s.power>100),typeName(s.type(yy,xx)),xx,yy, ...
            s.T(yy,xx)-273.15,remaining,s.water(yy,xx));
        set(statusText,'String',sprintfText);
        title(axMap,sprintf('Forest energy network  |  %.0f m x %.0f m',p.dx*p.nx,p.dx*p.ny));
    end

    function closeWindow(~,~)
        running = false;
        delete(fig);
    end
end

function s = newForest(p)
% Build a random but spatially clustered arrangement of vegetation.
rng(p.seed);
[nx,ny] = deal(p.nx,p.ny);
[X,Y] = meshgrid(1:nx,1:ny);
noise = conv2(rand(ny,nx),ones(9)/81,'same');
noise = (noise-min(noise(:)))/(max(noise(:))-min(noise(:)));
coverage = min(.98,p.density*(.65+.85*noise));
occupied = rand(ny,nx)<coverage;

% type 0 = bare ground; 1 = grass; 2 = shrubs; 3 = trees; 4 = rock
s.type = zeros(ny,nx);
r = rand(ny,nx);
treeProb = min(.8,p.treeFraction*(.55+.95*noise));
s.type(occupied & r < treeProb) = 3;
s.type(occupied & r >= treeProb & r < treeProb+.40) = 2;
s.type(occupied & s.type==0) = 1;

% Rock outcrops and scattered noncombustible areas.
rockPatch = ((X-.76*nx)/7).^2 + ((Y-.28*ny)/6).^2 < 1;
rocks = rockPatch | rand(ny,nx)<p.rockFraction;
if p.firebreak
    pathX = round(.62*nx + 2*sin(Y/5));
    rocks = rocks | abs(X-pathX)<=1;
end
s.type(rocks) = 4;

s.loading = zeros(ny,nx); % dry fuel, kg/m^2
r = rand(ny,nx);
s.loading(s.type==1) = .3 + .6*r(s.type==1);
s.loading(s.type==2) = 1.1 + 2.3*r(s.type==2);
s.loading(s.type==3) = 3.2 + 7.0*r(s.type==3);
s.dry0 = s.loading*p.dx^2;

fineFraction = zeros(ny,nx);
fineFraction(s.type==1) = .92;
fineFraction(s.type==2) = .68;
fineFraction(s.type==3) = .33;
s.fine = s.dry0 .* fineFraction;
s.coarse = s.dry0 - s.fine;
s.fine0 = s.fine;
s.coarse0 = s.coarse;

% Moisture is specified relative to dry mass; live vegetation is wetter.
s.water = s.dry0.*p.moisture;
s.water(s.type==2) = s.water(s.type==2)*1.18;
s.water(s.type==3) = s.water(s.type==3)*1.30;
s.water0 = s.water;
s.LHV = zeros(ny,nx);
s.LHV(s.type==1) = 16.5e6;
s.LHV(s.type==2) = 17.4e6;
s.LHV(s.type==3) = 18.0e6;
s.Tign = inf(ny,nx);
s.Tign(s.type==1)=545;
s.Tign(s.type==2)=565;
s.Tign(s.type==3)=585;
s.tauFine=ones(ny,nx)*40;
s.tauCoarse=ones(ny,nx)*180;
s.tauFine(s.type==1)=22;
s.tauFine(s.type==2)=38;
s.tauFine(s.type==3)=58;
s.tauCoarse(s.type==1)=70;
s.tauCoarse(s.type==2)=150;
s.tauCoarse(s.type==3)=290;
s.T=ones(ny,nx)*(p.ambientC+273.15);
s.lit=false(ny,nx);
s.incoming=zeros(ny,nx); % W from neighbors, before loss
s.power=zeros(ny,nx);    % W from dry-fuel conversion
s.time=0;
s.initialFuel=max(eps,sum(s.dry0(:)));
end

function s = igniteNear(s,y,x)
% External ignition is represented by initially heating a small fuel patch.
% The ignited cell starts dry; this is a starter ignition, not spontaneous.
[nr,nc] = size(s.type);
if y<1 || y>nr || x<1 || x>nc || ~ismember(s.type(y,x),1:3)
    [iy,ix] = find(s.type>=1 & s.type<=3);
    if isempty(ix), return; end
    [~,k] = min((ix-x).^2+(iy-y).^2);
    x=ix(k); y=iy(k);
end
for iy = max(1,y-1):min(nr,y+1)
    for ix = max(1,x-1):min(nc,x+1)
        if s.type(iy,ix)>=1 && s.type(iy,ix)<=3
            s.T(iy,ix)=950;
            s.water(iy,ix)=0;
            s.lit(iy,ix)=true;
        end
    end
end
end

function s = advance(s,p)
% Energy balance, where the heating/reaction terms are powers (W).
% A cell has four in-plane neighboring cells. Out-of-plane losses go to air.
T = s.T;
wetness = s.water;
remaining = s.fine+s.coarse;
canBurn = remaining>1e-8 & s.type>=1 & s.type<=3;
s.lit = s.lit | (T>=s.Tign & wetness<.005.*max(s.dry0,1e-9));
active = canBurn & s.lit & T>p.burnTempFloor;
rateFactor = min(1.6,max(.25,(T-420)/280));
dmFine = min(s.fine,p.dt*(s.fine./s.tauFine).*rateFactor.*active);
dmCoarse = min(s.coarse,p.dt*(s.coarse./s.tauCoarse).*rateFactor.*active);
s.fine = s.fine-dmFine;
s.coarse = s.coarse-dmCoarse;
s.power = (dmFine+dmCoarse).*s.LHV/p.dt;

% Directed flame heating. Wind makes heat stronger downwind. We normalize
% the four weights so no combustion energy is counted more than once.
weights = exp(p.windWeight*[p.wind,-p.wind,p.windVertical,-p.windVertical]);
weights = weights/sum(weights);
Pneighbors = p.heatNeighborFraction*s.power;
incoming = zeros(size(T));
incoming(:,2:end)   = incoming(:,2:end)   + weights(1)*Pneighbors(:,1:end-1); % east
incoming(:,1:end-1) = incoming(:,1:end-1) + weights(2)*Pneighbors(:,2:end);   % west
incoming(2:end,:)   = incoming(2:end,:)   + weights(3)*Pneighbors(1:end-1,:); % south
incoming(1:end-1,:) = incoming(1:end-1,:) + weights(4)*Pneighbors(2:end,:);   % north

% Temperature-driven, symmetric face exchange: what exits one cell enters
% the other. This can move heat across a bare/rocky cell without burning it.
Qface = p.G*(T(:,1:end-1)-T(:,2:end));
exchange = zeros(size(T));
exchange(:,1:end-1) = exchange(:,1:end-1)-Qface;
exchange(:,2:end)   = exchange(:,2:end)+Qface;
Qface = p.G*(T(1:end-1,:)-T(2:end,:));
exchange(1:end-1,:) = exchange(1:end-1,:)-Qface;
exchange(2:end,:)   = exchange(2:end,:)+Qface;

Ta = p.ambientC+273.15;
A = p.dx^2;
Qatmos = p.h*A*(T-Ta) + p.emissivity*p.sigma*A*(T.^4-Ta^4);
C = p.airCapacity + p.cpDry*(s.fine+s.coarse) ...
    + p.cpWater*s.water + p.rockCapacity*(s.type==4);
Qnet = p.heatLocalFraction*s.power + incoming+exchange-Qatmos;
Tpred = T+p.dt*Qnet./C;

% Evaporate water with energy that would otherwise heat above boiling.
% This is a simple latent-heat approximation, not detailed wet-wood drying.
waterEvap = min(s.water, C.*max(0,Tpred-p.boil)/p.latent);
waterLeft = s.water-waterEvap;
Tmid = Tpred-waterEvap*p.latent./C;
% At lower temperatures, humid air slows surface drying. This approximate
% rate is capped by the sensible heat available for evaporation.
slowEvap = p.dt*p.dryingRate*(1-p.relativeHumidity).*waterLeft ...
    .*min(2,max(0,(Tmid-315)/45));
slowEvap = min(slowEvap,waterLeft);
slowEvap = min(slowEvap,C.*max(Tmid-max(Ta,315),0)/p.latent);
s.water = waterLeft-slowEvap;
s.T = Tmid-slowEvap*p.latent./C;
s.T = max(220,s.T);   % numerical lower bound
s.incoming = incoming + max(exchange,0); % positive power arriving at cell
s.time = s.time + p.dt;
end

function rgb = forestRGB(s)
% Distinct colors for vegetation types and dynamic combustion state.
[nr,nc]=size(s.type);
rgb=zeros(nr,nc,3);
colors=[.77 .71 .60; .55 .73 .37; .33 .58 .28; .12 .35 .19; .47 .49 .48];
for t=0:4
    k=(s.type==t);
    for c=1:3
        layer=rgb(:,:,c);
        layer(k)=colors(t+1,c);
        rgb(:,:,c)=layer;
    end
end

consumed = (s.dry0>0) & ((s.fine+s.coarse)<.07*s.dry0);
warming = (s.dry0>0) & (s.T>365) & ~consumed;
burning = s.power>800;
for c=1:3
    layer=rgb(:,:,c);
    charcoal=[.23 .24 .22]; yellow=[.90 .77 .28]; orange=[1.0 .31 .04];
    layer(consumed)=charcoal(c);
    layer(warming)=yellow(c);
    layer(burning)=orange(c);
    rgb(:,:,c)=layer;
end
end

function name=typeName(t)
switch t
    case 0, name='bare ground';
    case 1, name='grass';
    case 2, name='shrub';
    case 3, name='tree';
    case 4, name='rock';
    otherwise, name='unknown';
end
end
