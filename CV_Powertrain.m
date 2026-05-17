% Extracting data from excelß
% drive_cycle_data = readtable('Drive_Cycle/track.xlsx');
% velocity_profile = [(1:length(drive_cycle_data.Car_Velocity_mps))' drive_cycle_data.Car_Velocity_mps];
% plot(velocity_profile(:,2));

clc;
clear;
%%
% Engine specifications
engine_bore = 0.086;                    % Bore diameter (m)
engine_stroke = 0.086;                  % Stroke length (m)
volume_displaced = engine_stroke * ((pi * (engine_bore)^2) / 4);
n_cylinder = 4;                         % Number of cylinders
idle_rpm = 700;                         % Idle speed (RPM)
redline_rpm = 6000;                     % Maximum speed (RPM)
rpm = (idle_rpm:100:redline_rpm);       % RPM array
calorific_value = 44000000;             % Fuel energy content (J/kg)
AFR_stoich = 14.6;                      % Stoichiometric air-fuel ratio
R = 287;                                % Gas constant (J/kg-K)
temp_in = 320;                          % Intake temperature (K)

% Load volumetric and thermal efficiency data
bsfc_data = load("Engine_Vol_Therm_Eff.mat");
vol_eff = bsfc_data.vol_eff;
vol_eff_intake_pressure = bsfc_data.vol_eff_MAP_in_Pa;
vol_eff_rpm = bsfc_data.vol_eff_RPM;
therm_eff = bsfc_data.Thermo_eff;
therm_eff_rpm = bsfc_data.Thermo_eff_RPM;
therm_eff_mass = bsfc_data.Thermo_eff_cyl_air_in_kg;

% Create meshgrid for volumetric efficiency
vol_eff_intake_pressure_array = vol_eff_intake_pressure(4,1):100:vol_eff_intake_pressure(end,end);
[vol_eff_rpm_cont, vol_eff_intake_pressure_cont] = meshgrid(rpm, vol_eff_intake_pressure_array);

% Preallocate engine performance matrices
n_pressure_points = length(vol_eff_intake_pressure_array);
n_rpm_points = length(rpm);
torque_engine_data = zeros(n_pressure_points, n_rpm_points);
mass_flow_rate_engine_data = zeros(n_pressure_points, n_rpm_points);
rpm_engine_data = vol_eff_rpm_cont;
power_engine_data = zeros(n_pressure_points, n_rpm_points);
bsfc_engine_data = zeros(n_pressure_points, n_rpm_points);
eta_conversion_engine_data = zeros(n_pressure_points, n_rpm_points);
fuel_mass_per_cycle_engine_data = zeros(n_pressure_points, n_rpm_points);
imep_gross_engine_data = zeros(n_pressure_points, n_rpm_points);
bmep_engine_data = zeros(n_pressure_points, n_rpm_points);
therm_eff_engine_data = zeros(n_pressure_points, n_rpm_points);

% Calculate engine performance across operating range
for i = 1:n_rpm_points
    for j = 1:n_pressure_points
        % Air density and mass flow calculations
        rho_air_engine = vol_eff_intake_pressure_array(j) / (R * temp_in);
        vol_eff_engine = interp2(vol_eff_rpm, vol_eff_intake_pressure, vol_eff, rpm(i), vol_eff_intake_pressure_array(j));
        mass_per_cycle_engine = (vol_eff_engine * volume_displaced * rho_air_engine);
        mass_flow_rate_engine = (mass_per_cycle_engine * (rpm(i) / (2 * 60)));
        fuel_mass_per_cycle_engine = mass_per_cycle_engine / AFR_stoich;
        fuel_mass_per_cycle_engine_data(j,i) = fuel_mass_per_cycle_engine;
        
        % Thermal efficiency and work
        therm_eff_engine = interp2(therm_eff_rpm, therm_eff_mass, therm_eff, rpm(i), mass_per_cycle_engine);
        therm_eff_engine_data(j,i) = therm_eff_engine;
        fuel_mass_flow_rate_engine = mass_flow_rate_engine / AFR_stoich;
        mass_flow_rate_engine_data(j,i) = fuel_mass_flow_rate_engine;
        work_engine = therm_eff_engine * fuel_mass_per_cycle_engine * calorific_value;
        imep_gross_engine = work_engine / volume_displaced;
        imep_gross_engine_data(j,i) = imep_gross_engine;
        
        % Pressure losses and BMEP
        exhaust_pressure_engine = 97708 + (70600 * 4 * (15.6/14.6)*mass_flow_rate_engine) - ...
                                  (38260 * 4 * (((15.6/14.6)*mass_flow_rate_engine)^2));
        imep_pump_engine = (vol_eff_intake_pressure_array(j) - exhaust_pressure_engine);
        fmep_engine = -((0.97 + (0.15 * (rpm(i)/(1000))) + (0.05 * ((rpm(i)/(1000))^2))) * 100000);
        bmep_engine = imep_gross_engine + imep_pump_engine + fmep_engine;
        bmep_engine_data(j,i) = bmep_engine;
        
        % BSFC and power calculations with limits
        bsfc_engine = fuel_mass_per_cycle_engine / (bmep_engine * volume_displaced);
        if bsfc_engine * 1000000 * 3600 <= 0
            bsfc_engine = 1500 / (3600000000);
            power_engine = 0;
        elseif bsfc_engine * 1000000 * 3600 > 1500
            bsfc_engine = 1500 / (1000000 * 3600);
            power_engine = (n_cylinder * fuel_mass_flow_rate_engine) / bsfc_engine;
        else
            power_engine = (n_cylinder * fuel_mass_flow_rate_engine) / bsfc_engine;
        end
        
        % Store calculated values
        bsfc_engine_data(j, i) = bsfc_engine * 1000000 * 3600;
        torque_engine = power_engine / (rpm(i) * ((2 * pi) / 60));
        torque_engine_data(j, i) = torque_engine;
        power_engine_data(j, i) = power_engine;
        eta_conversion = power_engine / (4 * fuel_mass_flow_rate_engine * calorific_value);
        eta_conversion_engine_data(j,i) = eta_conversion;
    end
end
%%

% Plot 1: BSFC contour map with torque and power curves
figure('Name', 'NA Engine BSFC Map', 'NumberTitle', 'off');
yyaxis right;
plot(rpm_engine_data(1,:), power_engine_data(end,:)/1000, 'r--', 'LineWidth', 1.5);
ylabel('Power (kW)');
hold on;
yyaxis left;
plot(rpm_engine_data(1,:), torque_engine_data(end,:), 'k--', 'LineWidth', 1.5);
xlabel('RPM');
ylabel('Torque (Nm)');
hold on;
contourf(rpm_engine_data, torque_engine_data, bsfc_engine_data);
clim([200, 1000]);
ylim([0,170]);
xlim([700, 6000]);
legend('Torque', 'BSFC (g/kWhr)', 'Power');
title('BSFC (g/kWhr) Map - Naturally Aspirated Engine');
hold off;

% Plot 2: Conversion efficiency contour
figure('Name', 'NA Engine Efficiency', 'NumberTitle', 'off');
plot(rpm_engine_data(1,:), torque_engine_data(end,:), 'LineWidth', 1.2);
hold on;
contour(rpm_engine_data, torque_engine_data, eta_conversion_engine_data, 'ShowText', 'on');
ylabel('Torque (Nm)');
xlabel('RPM');
title('Conversion Efficiency - Naturally Aspirated Engine');
hold off;

%%
% Transmission and gearing
gear = [3.54, 1.91, 1.31, 0.97, 0.71, 0.62];  % Gear ratios
gear_no = [1, 2, 3, 4, 5, 6];                 % Gear numbers
trans_eta = 0.96;                              % Transmission efficiency
trans_inertia = 0.04;                          % Transmission inertia (kg-m^2)
fdr = 4.21;                                    % Final drive ratio
driveline_eta = 0.95;                          % Driveline efficiency
fdr_inertia = 0.02;                            % Final drive inertia (kg-m^2)

% Vehicle parameters
radius = 0.4318;                               % Wheel radius (m)
curb_weight = 1377;                            % Vehicle mass (kg)
drag_coefficient = 0.29;                       % Aerodynamic drag coefficient
area_frontal = 2.18;                           % Frontal area (m^2)
rho_air = 1.21;                                % Air density (kg/m^3)
wheelbase = 2.75;                              % Wheelbase (m)
cg_height = 0.508;                             % Center of gravity height (m)
cg_front = wheelbase/2;                        % CG distance from front axle (m)
cg_rear = wheelbase/2;                         % CG distance from rear axle (m)
rolling_resistance_coefficient = 0.01;         % Rolling resistance coefficient
friction_coefficient = 0.85;                   % Tire-road friction coefficient
wheel_inertia = 0.95;                          % Wheel inertia for four wheels (kg-m^2)

% Load drive cycle and engine data
drive_cycle_data = readtable("Drive_Cycle/track.xlsx");
drive_cycle = [(1:length(drive_cycle_data.Car_Velocity_mps))' drive_cycle_data.Car_Velocity_mps];
load("Engine_Data.mat");

%%
rpm_reference_array = rpm_engine_data(1,:);
torque_max = torque_engine_data(end,:);
torque_reference_array = 0:1:max(torque_max);
fuel_rate_reference_matrix = zeros(length(torque_reference_array), length(rpm_reference_array));

for i = 1:length(torque_reference_array)
    for j = 1:length(rpm_reference_array)
        for n = 1:length(torque_engine_data(:,j))-1
            if torque_reference_array(i) > torque_engine_data(n,j) && ...
               torque_reference_array(i) <= torque_engine_data(n+1,j)
                slope_fuel = (mass_flow_rate_engine_data(n+1,j) - mass_flow_rate_engine_data(n,j)) / ...
                             (torque_engine_data(n+1,j) - torque_engine_data(n,j));
                fuel_rate_reference_matrix(i,j) = mass_flow_rate_engine_data(n,j) + ...
                                                  (slope_fuel * (torque_reference_array(i) - torque_engine_data(n,j)));
            end
        end
        if isnan(fuel_rate_reference_matrix(i,j))
            fuel_rate_reference_matrix(i,j) = 0;
        end
    end
end

%%
% Define operating range
speed = 0:1:52;                        % Vehicle speed range (m/s)
peddle_position = 0.1:0.05:1;          % Pedal position range (10% to 100%)
max_engine_power = max((rpm_engine_data(1,:) * (pi/30)) .* torque_engine_data(end,:));

% Calculate iso-power curves
iso_power = zeros(1, length(peddle_position));
for i = 1:length(peddle_position)
    iso_power(i) = peddle_position(i) * max_engine_power * trans_eta * driveline_eta;
end

% Preallocate shift logic arrays
eng_rpm_shift = zeros(length(peddle_position), length(speed), length(gear));
req_power_shift = zeros(length(peddle_position), length(speed), length(gear));
req_torque_shift = zeros(length(peddle_position), length(speed), length(gear));
BSFC_torq_shift = 2000 * ones(length(peddle_position), length(speed), length(gear));
minBSFC = zeros(length(peddle_position), length(speed));
gear_selected = zeros(length(peddle_position), length(speed));

% Calculate BSFC for all speed/pedal/gear combinations
for i = 1:length(speed)
    for k = 1:length(peddle_position)
        for n = 1:length(gear)
            eng_rpm_shift(k,i,n) = (speed(i) * 60 * fdr * gear(n)) / (radius * 2 * pi);
            req_power_shift(k,i,n) = peddle_position(k) * max_engine_power;
            if eng_rpm_shift(k,i,n) <= 6000
                if eng_rpm_shift(k,i,n) <= 700
                    max_torq = max(torque_engine_data(:,1));
                    torq_rpm = linspace(0, max_torq, length(torque_engine_data(:,1)))';
                    BSFC_rpm = bsfc_engine_data(:,1);
                else
                    [~, rpm_idx] = min(abs(rpm_reference_array - eng_rpm_shift(k,i,n)));
                    torq_rpm = torque_engine_data(:, rpm_idx);
                    max_torq = max(torq_rpm);
                    BSFC_rpm = bsfc_engine_data(:, rpm_idx);
                end
                req_torque_shift(k,i,n) = min(max_torq, ...
                    ((req_power_shift(k,i,n) * 60) / (eng_rpm_shift(k,i,n) * 2 * pi)));
                for p = 2:length(torq_rpm)
                    if ~isnan(torq_rpm(p-1)) && ~isnan(torq_rpm(p)) && ...
                       ~isnan(BSFC_rpm(p-1)) && ~isnan(BSFC_rpm(p))
                        if torq_rpm(p-1) <= req_torque_shift(k,i,n) && ...
                           torq_rpm(p) >= req_torque_shift(k,i,n)
                            slope = (BSFC_rpm(p) - BSFC_rpm(p-1)) / ...
                                    (torq_rpm(p) - torq_rpm(p-1));
                            BSFC_torq_shift(k,i,n) = BSFC_rpm(p-1) + ...
                                (slope * (req_torque_shift(k,i,n) - torq_rpm(p-1)));
                            break;
                        end
                    end
                end
                if BSFC_torq_shift(k,i,n) == 2000
                    BSFC_torq_shift(k,i,n) = (7-n) * 2000;
                end
            else
                BSFC_torq_shift(k,i,n) = NaN;
            end
        end
        [minBSFC(k,i), gear_selected(k,i)] = min(BSFC_torq_shift(k,i,:));
    end
end

[vel_plot, peddle_pos_plot] = meshgrid(speed, peddle_position);
figure;
surf(speed, peddle_position, gear_selected);
clim([1 6])
xlabel('Vehicle Speed (m/s');
ylabel('Peddle Position');
zlabel('Gear');
grid on;

%% 

% Preallocate arrays
rpm_speed_gear = zeros(1, length(gear));
torque_max_gear = zeros(1, length(gear));
torque_demand_gear = zeros(1, length(gear));
torque_available_gear = zeros(1, length(gear));
torque_reference = zeros(1, length(torque_engine_data(:,1)));
bsfc_reference = zeros(1, length(bsfc_engine_data(:,1)));
bsfc_best = zeros(length(iso_power), length(speed));
torque_constant_power = zeros(1, length(rpm_reference_array));
bsfc_constant_power = zeros(1, length(rpm_reference_array));
rpm_optimum_shift = zeros(1, length(iso_power));
torque_optimum_shift = zeros(1, length(iso_power));

% Calculate optimum shift points for each power level
for i = 1:length(iso_power)
    for j = 1:length(rpm_reference_array)
        torque_shift_instant = (iso_power(i) * 60) / (rpm_reference_array(j) * 2 * pi);
        if torque_shift_instant > max(torque_engine_data(:,j))
            torque_shift_instant = NaN;
        end
        torque_constant_power(j) = torque_shift_instant;
        bsfc_constant_power(j) = interp1q(torque_engine_data(:,j), ...
                                          bsfc_engine_data(:,j), ...
                                          torque_shift_instant);
    end
    [bsfc_optimum, index] = min(bsfc_constant_power);
    rpm_optimum_shift(i) = rpm_reference_array(index);
    torque_optimum_shift(i) = torque_constant_power(index);
end

%%
figure('Name', 'BSFC Map with Shift Line', 'NumberTitle', 'off');
yyaxis right;
plot(rpm_engine_data(1,:), power_engine_data(end,:)/1000, 'g--', 'LineWidth', 2);
ylabel('Power (kW)');
hold on;
yyaxis left;
plot(rpm_engine_data(1,:), torque_engine_data(end,:), 'r--', 'LineWidth', 2);
xlabel('RPM');
ylabel('Torque (Nm)');
hold on;
contourf(rpm_engine_data, torque_engine_data, bsfc_engine_data);
clim([200, 1000]);
ylim([0,170]);
xlim([700, 6000]);
hold on;
plot(rpm_optimum_shift, torque_optimum_shift, 'y-', 'LineWidth', 1.5);
hold on;
legend('Torque Max', 'BSFC (g/kWhr)', 'Optimum shift line', 'Maximum Power');
title('BSFC Map with Optimum Shift Line');
hold off;

%%
fprintf('Running Simulink simulation...\n');
open_system("AuE6610_Project_CV");
sim("AuE6610_Project_CV");
set_param('AuE6610_Project_CV/Driver/Manual Switch', 'sw', '1');
set_param('AuE6610_Project_CV/engine/To Workspace1', 'Commented', 'off');
set_param('AuE6610_Project_CV/engine/To Workspace2', 'Commented', 'off');
set_param('AuE6610_Project_CV/engine/To Workspace3', 'Commented', 'on');
set_param('AuE6610_Project_CV/engine/To Workspace4', 'Commented', 'on');
sim("AuE6610_Project_CV");
close_system("AuE6610_Project_CV", 0);
fprintf('Simulink simulation complete.\n\n');

%%
figure('Name', 'Drive Cycle Operating Points', 'NumberTitle', 'off');
yyaxis right;
plot(rpm_engine_data(1,:), power_engine_data(end,:)/1000, 'g--', 'LineWidth', 2);
ylabel('Power (kW)');
hold on;
yyaxis left;
plot(rpm_engine_data(1,:), torque_engine_data(end,:), 'r--', 'LineWidth', 2);
xlabel('RPM');
ylabel('Torque (Nm)');
hold on;
contourf(rpm_engine_data, torque_engine_data, bsfc_engine_data);
clim([200, 1000]);
ylim([0,170]);
xlim([700, 6000]);
hold on;
plot(rpm_optimum_shift, torque_optimum_shift, 'y-', 'LineWidth', 1.5);
hold on;
scatter(rpm_drive_cycle, torque_drive_cycle, 10, 'filled', 'red');
hold on;
scatter(rpm_drive_cycle_wot, torque_drive_cycle_wot, 10, 'filled', 'black');
legend('Torque Max', 'BSFC (g/kWhr)', 'Optimum shift line', ...
       'Operating Points_FTP', 'Operating Points WOT', 'Maximum Power');
title('BSFC Map with Drive Cycle Operating Points');
hold off;

% Calculate peak power and fuel economy
peak_power = max((pi * rpm_drive_cycle / 30) .* torque_drive_cycle) / 1000;
fprintf('The peak power at crankshaft for FTP drivecycle is %.2f kW\n', peak_power);

total_fuel_consumed = fuel_drive_cycle(end);
total_distance = 0.000621371 * dist(end);
mpg = (3.78541 * 0.74 * total_distance) / total_fuel_consumed;
fprintf('The MPG of the vehicle for given drivecycle is %.3f\n\n', mpg);

%% 

% Turbocharged engine specifications
engine_bore = 0.082;
engine_stroke = 0.082;
volume_displaced = engine_stroke * ((pi * (engine_bore)^2) / 4);
n_cylinder = 4;
idle_rpm = 500;
redline_rpm = 6800;
rpm = (idle_rpm:100:redline_rpm);
calorific_value = 44000000;
rho_gas = 740;
AFR_stoich = 14.6;
rho_air = 1.18;
R = 287;
temp_in = 320;

% Load efficiency data
bsfc_data = load("Engine_Vol_Therm_Eff.mat");
therm_eff = bsfc_data.Thermo_eff;
therm_eff_rpm = bsfc_data.Thermo_eff_RPM;
therm_eff_mass = bsfc_data.Thermo_eff_cyl_air_in_kg;

% Turbocharger operating points
rpm_turbo = [1800 2800 3800 4800 5800 6000];
mass_per_cycle_turbo = [0.000615 0.000885 0.00106 0.00111 0.00116 0.00117];
boost_pressure = [24131.7 68947.6 89631.8 89631.8 89631.8 89631.8];
pmep_turbo = [-5000 -25000 -23000 -9000 12000 32000];

% Interpolate turbo data
rpm_turbo_continue = 700:100:6000;
mass_per_cycle_turbo = interp1(rpm_turbo, mass_per_cycle_turbo, ...
                               rpm_turbo_continue, "linear", "extrap");
boost_pressure_continue = interp1(rpm_turbo, boost_pressure, ...
                                  rpm_turbo_continue, "linear", "extrap");
pmep_turbo = interp1(rpm_turbo, pmep_turbo, rpm_turbo_continue, ...
                     "linear", "extrap");
[rpm_plot_turbo, x] = meshgrid(rpm_turbo_continue, mass_per_cycle_turbo);

% Preallocate turbo engine matrices
n_turbo_rpm = length(rpm_turbo_continue);
n_mass_points = length(mass_per_cycle_turbo);
torque_turbo_data = zeros(n_mass_points, n_turbo_rpm);
power_turbo_data = zeros(n_mass_points, n_turbo_rpm);
bsfc_turbo_data = zeros(n_mass_points, n_turbo_rpm);
eta_conversion_turbo_data = zeros(n_mass_points, n_turbo_rpm);
fuel_mass_per_cycle_turbo_data = zeros(n_mass_points, n_turbo_rpm);
imep_gross_engine_data = zeros(n_mass_points, n_turbo_rpm);
bmep_turbo_data = zeros(n_mass_points, n_turbo_rpm);
therm_eff_engine_data = zeros(n_mass_points, n_turbo_rpm);

% Calculate turbocharged engine performance
for i = 1:n_turbo_rpm
    for j = 1:n_mass_points
        % Mass flow and fuel calculations
        mass_flow_rate_turbo = (mass_per_cycle_turbo(j) * (rpm_turbo_continue(i) / (2 * 60)));
        fuel_mass_per_cycle_turbo = mass_per_cycle_turbo(j) / AFR_stoich;
        fuel_mass_per_cycle_turbo_data(j,i) = fuel_mass_per_cycle_turbo;
        
        % Thermal efficiency
        therm_eff_engine = interp2(therm_eff_rpm, therm_eff_mass, therm_eff, ...
                                   rpm_turbo_continue(i), mass_per_cycle_turbo(j));
        therm_eff_engine_data(j,i) = therm_eff_engine;
        fuel_mass_flow_rate_turbo = mass_flow_rate_turbo / AFR_stoich;
        
        % Work and IMEP
        work_engine = therm_eff_engine * fuel_mass_per_cycle_turbo * calorific_value;
        imep_gross_engine = work_engine / volume_displaced;
        imep_gross_engine_data(j,i) = imep_gross_engine;
        
        % Pressure calculations
        exhaust_pressure_engine = 97708 + (70600 * 4 * (15.6/14.6) * mass_flow_rate_turbo) - ...
                                  (38260 * 4 * (((15.6/14.6) * mass_flow_rate_turbo)^2));
        imep_pump_turbo = (boost_pressure_continue(j) - exhaust_pressure_engine);
        fmep_turbo = -((0.97 + (0.15 * (rpm_turbo_continue(i)/1000)) + ...
                       (0.05 * ((rpm_turbo_continue(i)/1000)^2))) * 100000);
        bmep_turbo = imep_gross_engine + pmep_turbo(j) + fmep_turbo;
        bmep_turbo_data(j,i) = bmep_turbo;
        
        % BSFC and power with validity checks
        bsfc_turbo = fuel_mass_per_cycle_turbo / (bmep_turbo * volume_displaced);
        if bmep_turbo <= 0 || isnan(bmep_turbo)
            bsfc_turbo = NaN;
            power_turbo = NaN;
        else
            bsfc_turbo = min(bsfc_turbo, 2000 / (1000000 * 3600));
            power_turbo = (n_cylinder * fuel_mass_flow_rate_turbo) / bsfc_turbo;
        end
        
        % Store results
        bsfc_turbo_data(j, i) = bsfc_turbo * 1000000 * 3600;
        torque_turbo = power_turbo / (rpm_turbo_continue(i) * ((2 * pi) / 60));
        torque_turbo_data(j, i) = torque_turbo;
        power_turbo_data(j, i) = power_turbo;
        eta_conversion = power_turbo / (n_cylinder * fuel_mass_flow_rate_turbo * calorific_value);
        eta_conversion_turbo_data(j,i) = eta_conversion;
    end
end

%%
% Create interpolated grid for smoother contours
[rpm_q, torque_q] = meshgrid( ...
    linspace(min(rpm_turbo_continue), max(rpm_turbo_continue), 200), ...
    linspace(min(torque_turbo_data(:)), max(torque_turbo_data(:)), 200));
bsfc_interp = griddata(rpm_plot_turbo, torque_turbo_data, bsfc_turbo_data, ...
                       rpm_q, torque_q);

% Plot turbocharged engine BSFC map
figure('Name', 'Turbocharged Engine BSFC Map', 'NumberTitle', 'off');
yyaxis right;
plot(rpm_turbo_continue, power_turbo_data(end,:)/1000, 'r--', 'LineWidth', 1.5);
ylabel('Power (kW)');
hold on;
yyaxis left;
plot(rpm_turbo_continue, torque_turbo_data(end,:), 'k--', 'LineWidth', 1.5);
xlabel('RPM');
ylabel('Torque (Nm)');
hold on;
contourf(rpm_q, torque_q, bsfc_interp, 10);
colorbar;
clim([200, 2000]);
ylim([0, 350]);
xlim([700, 6000]);
legend('Torque', 'BSFC (g/kWhr)', 'Power');
title('BSFC (g/kWhr) Map - Turbocharged Engine');
hold off;

% Plot turbocharged engine efficiency
figure('Name', 'Turbocharged Engine Efficiency', 'NumberTitle', 'off');
plot(rpm_turbo_continue, torque_turbo_data(end,:), 'LineWidth', 1.2);
hold on;
contour(rpm_plot_turbo, torque_turbo_data, eta_conversion_turbo_data, ...
        'ShowText', 'on');
ylabel('Torque (Nm)');
xlabel('RPM');
title('Conversion Efficiency - Turbocharged Engine');
hold off;