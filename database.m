% Extracting data from excel

drive_cycle_data = readtable('Drive_Cycle/track.xlsx');
velocity_profile = [(1:length(drive_cycle_data.Car_Velocity_mps))' drive_cycle_data.Car_Velocity_mps];
plot(velocity_profile(:,2));
%%
clc;
clear;

% Given data
engine_bore = 0.086;
engine_stroke = 0.086;
volume_displaced = engine_stroke * ((pi * (engine_bore)^2) / 4);
n_cylinder = 4;
idle_rpm = 700;
redline_rpm = 6000;
rpm = (idle_rpm:100:redline_rpm);
calorific_value = 44000000;
AFR_stoich = 14.6;
R = 287;
temp_in = 320;
bsfc_data = load("Engine_Vol_Therm_Eff.mat");
vol_eff = bsfc_data.vol_eff;
vol_eff_intake_pressure = bsfc_data.vol_eff_MAP_in_Pa;
vol_eff_rpm = bsfc_data.vol_eff_RPM;
therm_eff = bsfc_data.Thermo_eff;
therm_eff_rpm = bsfc_data.Thermo_eff_RPM;
therm_eff_mass = bsfc_data.Thermo_eff_cyl_air_in_kg;
vol_eff_intake_pressure_array = vol_eff_intake_pressure(4,1):100:vol_eff_intake_pressure(end,end);
[vol_eff_rpm_cont, vol_eff_intake_pressure_cont] = meshgrid(rpm, vol_eff_intake_pressure_array);

% Data generation for plot
torque_engine_data = zeros(length(vol_eff_intake_pressure_array),length(rpm));
mass_flow_rate_engine_data = zeros(length(vol_eff_intake_pressure_array),length(rpm));
rpm_engine_data = vol_eff_rpm_cont;
power_engine_data = zeros(length(vol_eff_intake_pressure_array),length(rpm));
bsfc_engine_data = zeros(length(vol_eff_intake_pressure_array),length(rpm));
eta_conversion_engine_data = zeros(length(vol_eff_intake_pressure_array),length(rpm));
fuel_mass_per_cycle_engine_data = zeros(length(vol_eff_intake_pressure_array),length(rpm));
imep_gross_engine_data = zeros(length(vol_eff_intake_pressure_array),length(rpm));
bmep_engine_data = zeros(length(vol_eff_intake_pressure_array),length(rpm));
therm_eff_engine_data = zeros(length(vol_eff_intake_pressure_array),length(rpm));
for i = 1 : length(rpm)
    for j = 1 : length(vol_eff_intake_pressure_array)
        rho_air_engine = vol_eff_intake_pressure_array(j) / (R * temp_in);
        vol_eff_engine = interp2(vol_eff_rpm, vol_eff_intake_pressure, vol_eff, rpm(i), vol_eff_intake_pressure_array(j));
        mass_per_cycle_engine = (vol_eff_engine * volume_displaced * rho_air_engine);
        mass_flow_rate_engine = (mass_per_cycle_engine * (rpm(i) / (2 * 60)));
        fuel_mass_per_cycle_engine = mass_per_cycle_engine / AFR_stoich;
        fuel_mass_per_cycle_engine_data(j,i) = fuel_mass_per_cycle_engine;
        therm_eff_engine = interp2(therm_eff_rpm, therm_eff_mass, therm_eff, rpm(i), mass_per_cycle_engine);
        therm_eff_engine_data(j,i) = therm_eff_engine;
        fuel_mass_flow_rate_engine = mass_flow_rate_engine / AFR_stoich;
        mass_flow_rate_engine_data(j,i) = fuel_mass_flow_rate_engine;
        work_engine = therm_eff_engine * fuel_mass_per_cycle_engine * calorific_value;
        imep_gross_engine = work_engine / volume_displaced;
        imep_gross_engine_data(j,i) = imep_gross_engine;
        exhaust_pressure_engine = 97708 + (70600 * 4 * (15.6/14.6)*mass_flow_rate_engine) - (38260 * 4 * (((15.6/14.6)*mass_flow_rate_engine)^2));
        imep_pump_engine = (vol_eff_intake_pressure_array(j) - exhaust_pressure_engine);
        fmep_engine = -((0.97 + (0.15 * (rpm(i)/(1000))) + (0.05 * ((rpm(i)/(1000))^2))) * 100000);
        bmep_engine = imep_gross_engine + imep_pump_engine + fmep_engine;
        bmep_engine_data(j,i) = bmep_engine;
        bsfc_engine = fuel_mass_per_cycle_engine / (bmep_engine * volume_displaced);
        if bsfc_engine * 1000000 * 3600 <= 0
            bsfc_engine = 1000 /(3600000000);
            power_engine = 0;
        elseif bsfc_engine * 1000000 * 3600 > 1000
            bsfc_engine = 1000 / (1000000 * 3600);
            power_engine = (n_cylinder * fuel_mass_flow_rate_engine) / bsfc_engine;
        else
            power_engine = (n_cylinder * fuel_mass_flow_rate_engine) / bsfc_engine;
        end
        bsfc_engine_data(j, i) = bsfc_engine * 1000000 * 3600;
        torque_engine = power_engine / (rpm(i) * ((2 * pi) / 60));
        torque_engine_data(j, i) = torque_engine;
        power_engine_data(j, i) = power_engine;
        eta_conversion = power_engine / (4 * fuel_mass_flow_rate_engine * calorific_value);
        eta_conversion_engine_data(j,i) = eta_conversion;
    end
end

% Plotting the results
figure;
yyaxis right;
plot(rpm_engine_data(1,:), power_engine_data(end,:)/1000, 'r--', Linewidth=1.5);
ylabel('Power (kW)');
hold on;
yyaxis left;
plot(rpm_engine_data(1,:), torque_engine_data(end,:),'k--', Linewidth=1.5);
xlabel('RPM');
ylabel('Torque (Nm)');
hold on;
contourf(rpm_engine_data, torque_engine_data, bsfc_engine_data);
clim([200, 1000]);
ylim([0,150]);
xlim([700, 6000]);
legend('Torque', 'BSFC (g/kWhr)', 'Power');
title('BSFC (g/kWhr) Map');
hold off;

figure;
plot(rpm_engine_data(1,:), torque_engine_data(end,:), Linewidth=1.2);
hold on;
contour(rpm_engine_data, torque_engine_data, eta_conversion_engine_data, 'ShowText','on');
ylabel('Torque (Nm)');
xlabel('RPM')




% Given Data
gear = [3.54, 1.91, 1.31, 0.97, 0.71, 0.62];                       % Gear ratio
gear_no = [1,2,3,4,5,6];    % Gear number
trans_eta = 0.96;           % Transmission efficiencty
trans_inertia = 0.04;       % Transmission inertia
fdr = 4.21;                 % Final drive ratio
driveline_eta = 0.95;       % Driveline efficiency`
fdr_inertia = 0.02;         % Final drive inertia
radius = 0.4318;            % Wheel radius in m
curb_weight = 1377;         % Vehicle mass in kg
drag_coefficient = 0.29;    % Aero drag coefficient
area_frontal = 2.18;      % Frontal area
rho_air = 1.21;             % Air density
wheelbase = 2.75;            % Wheelbase in meters
cg_height = 0.508;          % CG height in meters
cg_front = wheelbase/2;
cg_rear = wheelbase/2;
rolling_resistance_coefficient = 0.01; % Rolling resistance coefficient
friction_coefficient = 0.85;            % Friction coefficient
wheel_inertia = 0.95;                   % wheel inertia for four wheels
drive_cycle_data = readtable("Drive_Cycle/track.xlsx"); % Loading speed profile
drive_cycle = [(1:length(drive_cycle_data.Car_Velocity_mps))' drive_cycle_data.Car_Velocity_mps];
load("Engine_Data.mat");
rpm_reference_array = rpm_engine_data(1,:);
torque_max = torque_engine_data(end,:);
torque_reference_array = 0:1:max(torque_max);
fuel_rate_reference_matrix = zeros(length(torque_reference_array),length(rpm_reference_array));
for i = 1:length(torque_reference_array)
    for j = 1:length(rpm_reference_array)
        for n = 1:length(torque_engine_data(:,j))-1
            if torque_reference_array(i) > torque_engine_data(n,j) && torque_reference_array(i) <= torque_engine_data(n+1,j)
                slope_fuel = (mass_flow_rate_engine_data(n+1,j) - mass_flow_rate_engine_data(n,j))/(torque_engine_data(n+1,j)-torque_engine_data(n,j));
                fuel_rate_reference_matrix(i,j) = mass_flow_rate_engine_data(n,j) + (slope_fuel * (torque_reference_array(i)-torque_engine_data(n,j)));
            end
            if isnan(fuel_rate_reference_matrix(i,j))
                fuel_rate_reference_matrix(i,j) = 0;
            end
        end
    end
end

% Starting with vehicle speed
speed = 1:1:52;
peddle_position = 0.1:0.05:1;
max_engine_power = max((rpm_engine_data(1,:) * ( pi /30)) .* torque_engine_data(end,:));

iso_power = zeros(1, length(peddle_position));
for i = 1:length(peddle_position)
    iso_power(i) = peddle_position(i) * max_engine_power * trans_eta * driveline_eta;
end

rpm_speed_gear = zeros(1,length(gear));
torque_max_gear = zeros(1,length(gear));
torque_demand_gear = zeros(1,length(gear));
torque_available_gear = zeros(1,length(gear));
torque_reference = zeros(1,length(torque_engine_data(:,1)));
bsfc_reference = zeros(1,length(bsfc_engine_data(:,1)));
bsfc_best = zeros(length(iso_power),length(speed));
gear_selected = zeros(length(iso_power), length(speed));

% % --- Corrected Gear Map Computation (NO INTERPOLATION FUNCTIONS) ---
% 
% bsfc_best = zeros(length(iso_power),length(speed));
% gear_selected = zeros(length(iso_power), length(speed));
% 
% for i = 1:length(speed)
% 
%     % --- Compute engine RPM in each gear ---
%     for g = 1:length(gear)
%         rpm_val = gear(g) * fdr * (speed(i)/radius) * (30/pi);
%         if rpm_val < 500 || rpm_val > 6800
%             rpm_speed_gear(g) = 0;
%         else
%             rpm_speed_gear(g) = rpm_val;
%         end
%     end
% 
%     % --- Maximum torque allowed in each gear at that RPM ---
%     for g = 1:length(gear)
%         if rpm_speed_gear(g) == 0
%             torque_max_gear(g) = 0;
%         else
%             torque_max_gear(g) = interp1(rpm_reference_array, torque_max, rpm_speed_gear(g), "linear", 0);
%         end
%     end
% 
%     % Loop through pedal positions (iso-power lines)
%     for j = 1:length(iso_power)
% 
%         % --- Torque demand at each gear ---
%         for g = 1:length(gear)
%             if rpm_speed_gear(g) == 0
%                 torque_demand_gear(g) = 0;
%             else
%                 torque_demand_gear(g) = iso_power(j) / (rpm_speed_gear(g)*(pi/30));
%             end
%         end
% 
%         % --- Final available torque in each gear ---
%         for g = 1:length(gear)
%             torque_available_gear(g) = min(torque_demand_gear(g), torque_max_gear(g));
%         end
% 
%         % --- Compute BSFC via MANUAL bilinear interpolation ---
%         bsfc_instant_array = zeros(1, length(gear));
% 
%         for r = 1:length(gear)
% 
%             t_avail = torque_available_gear(r);
%             rpm_q   = rpm_speed_gear(r);
% 
%             if t_avail <= 0 || rpm_q <= 0
%                 bsfc_instant_array(r) = 0;
%                 continue
%             end
% 
%             % ----------------------------------------------------
%             % 1) Find RPM bracket  rpm(l) ≤ rpm_q ≤ rpm(l+1)
%             % ----------------------------------------------------
%             l = find(rpm_reference_array <= rpm_q, 1, "last");
%             if isempty(l) || l == length(rpm_reference_array)
%                 bsfc_instant_array(r) = 0;
%                 continue
%             end
% 
%             rpm_low  = rpm_reference_array(l);
%             rpm_high = rpm_reference_array(l+1);
% 
%             % ----------------------------------------------------
%             % 2) Find torque bracket  t(m) ≤ t_avail ≤ t(m+1)
%             % ----------------------------------------------------
%             m = find(torque_reference_array <= t_avail, 1, "last");
%             if isempty(m) || m == length(torque_reference_array)
%                 bsfc_instant_array(r) = 0;
%                 continue
%             end
% 
%             t_low  = torque_reference_array(m);
%             t_high = torque_reference_array(m+1);
% 
%             % ----------------------------------------------------
%             % 3) Extract BSFC values around target point
%             % ----------------------------------------------------
%             Q11 = bsfc_engine_data(m,   l);
%             Q21 = bsfc_engine_data(m,   l+1);
%             Q12 = bsfc_engine_data(m+1, l);
%             Q22 = bsfc_engine_data(m+1, l+1);
% 
%             % ----------------------------------------------------
%             % 4) Normalized coordinates inside the cell
%             % ----------------------------------------------------
%             xr = (rpm_q - rpm_low) / (rpm_high - rpm_low);
%             yr = (t_avail - t_low) / (t_high - t_low);
% 
%             % ----------------------------------------------------
%             % 5) Bilinear interpolation
%             % ----------------------------------------------------
%             bsfc_val = ...
%                 Q11 * (1-xr) * (1-yr) + ...
%                 Q21 * xr     * (1-yr) + ...
%                 Q12 * (1-xr) * yr     + ...
%                 Q22 * xr     * yr;
% 
%             bsfc_instant_array(r) = bsfc_val;
% 
%         end  % end gear loop
% 
%         % --- Select Best Gear ---
%         valid = (bsfc_instant_array > 0);
% 
%         if any(valid)
%             valid_idx = find(valid);
%             [~, k] = min(bsfc_instant_array(valid));
%             chosen = valid_idx(k);
% 
%             gear_selected(j,i) = gear_no(chosen);
%             bsfc_best(j,i)     = bsfc_instant_array(chosen);
%         end
% 
%     end  % pedal loop
% end  % speed loop

for i = 1:length(speed)
    for g = 1:length(rpm_speed_gear)
        if (gear(g) * fdr * (speed(i)/radius) * (30/pi)) > redline_rpm
            rpm_speed_gear(g) = 0;
        elseif (gear(g) * fdr * (speed(i)/radius) * (30/pi)) < idle_rpm
            rpm_speed_gear(g) = 0;
        else
            rpm_speed_gear(g) = (gear(g) * fdr * (speed(i)/radius) * (30/pi));
        end
    end
    for g = 1:length(gear)
        if rpm_speed_gear(g) == 0
            torque_max_gear(g) = 0;
        else
            torque_max_gear(g) = interp1(rpm_reference_array, torque_max, rpm_speed_gear(g), "linear", 0);
        end
    end
    for j = 1:length(iso_power)
        bsfc_instant_array = zeros(1, length(gear));
        for g = 1:length(gear)
            if rpm_speed_gear(g) == 0
                torque_demand_gear(g) = 0;
            else
                torque_demand_gear(g) = iso_power(j) / (rpm_speed_gear(g)*(pi/30));
            end
        end
        for t = 1:length(torque_available_gear)
            torque_available_gear(t) = min(torque_demand_gear(t),torque_max_gear(t));
        end
        for r = 1:length(gear)
            if torque_available_gear(r) == 0 || rpm_speed_gear(r) == 0
                bsfc_instant_array(r) = 0;
                continue
            end
            rpm_q = rpm_speed_gear(r);
            t_q   = torque_available_gear(r);
            l = 0;
            for k = 1:(length(rpm_reference_array)-1)
                if rpm_q >= rpm_reference_array(k) && rpm_q <= rpm_reference_array(k+1)
                    l = k;
                    break
                end
            end
            if l == 0
                bsfc_instant_array(r) = 0;
                continue
            end
            for m = 1:length(torque_reference_array)-1
                slope_torque = (torque_engine_data(m+1, l) - torque_engine_data(m, l)) / (torque_reference_array(m+1) - torque_reference_array(m));
                slope_torque2 = (torque_engine_data(m+1, l+1) - torque_engine_data(m, l+1)) / (torque_reference_array(m+1) - torque_reference_array(m));
                torque_low_rpm  = torque_engine_data(m, l)   + slope_torque  * (t_q - torque_reference_array(m));
                torque_high_rpm = torque_engine_data(m, l+1) + slope_torque2 * (t_q - torque_reference_array(m));
                slope_bsfc  = (bsfc_engine_data(m+1, l) - bsfc_engine_data(m, l)) / (torque_reference_array(m+1) - torque_reference_array(m));
                slope_bsfc2 = (bsfc_engine_data(m+1, l+1) - bsfc_engine_data(m, l+1)) / (torque_reference_array(m+1) - torque_reference_array(m));
                bsfc_low_rpm  = bsfc_engine_data(m, l)   + slope_bsfc  * (t_q - torque_reference_array(m));
                bsfc_high_rpm = bsfc_engine_data(m, l+1) + slope_bsfc2 * (t_q - torque_reference_array(m));
                if t_q >= torque_reference_array(m) && t_q <= torque_reference_array(m+1)
                    rpm_ratio = (rpm_q - rpm_reference_array(l)) / (rpm_reference_array(l+1) - rpm_reference_array(l));
                    bsfc_val = bsfc_low_rpm + rpm_ratio * (bsfc_high_rpm - bsfc_low_rpm);
                    bsfc_instant_array(r) = bsfc_val;
                    break
                end
            end
            valid = (bsfc_instant_array > 0);
            if any(valid)
                valid_idx = find(valid);
                [~, k] = min(bsfc_instant_array(valid));
                chosen = valid_idx(k);
                gear_selected(j,i) = gear_no(chosen);
                bsfc_best(j,i)     = bsfc_instant_array(chosen);
            end
        end
    end
end

% Plotting Gearmap
[vel_plot, peddle_pos_plot] = meshgrid(speed, peddle_position);
figure;
surf(vel_plot,peddle_pos_plot,gear_selected);
clim([1 6])
xlabel('Vehicle Speed (m/s');
ylabel('Peddle Position');
zlabel('Gear');
grid on;

% Optimal Shift line
bsfc_constant_power = zeros(1,length(rpm_reference_array));
torque_constant_power = zeros(1,length(rpm_reference_array));
torque_optimum_shift = zeros(1,length(iso_power));
rpm_optimum_shift = zeros(1,length(iso_power));
for i = 1:length(iso_power)
    for j = 1:length(rpm_reference_array)
        torque_shift_instant = iso_power(i) / (rpm_reference_array(j)*(pi/30));
        if torque_shift_instant > torque_max(j)
            torque_shift_instant = NaN;
        end
        torque_constant_power(j) = torque_shift_instant;
        bsfc_constant_power(j) = interp1q(torque_engine_data(:,j),bsfc_engine_data(:,j),torque_shift_instant);
    end
    [bsfc_optimum,index] = min(bsfc_constant_power);
    rpm_optimum_shift(i) = rpm_reference_array(index);
    torque_optimum_shift(i) = torque_constant_power(index);
end

% Plotting BSFC contour
figure;
yyaxis right;
plot(rpm_engine_data(1,:), power_engine_data(end,:)/1000, 'g--', Linewidth=2);
ylabel('Power (kW)');
hold on;
yyaxis left;
plot(rpm_engine_data(1,:), torque_engine_data(end,:),'r--', Linewidth=2);
xlabel('RPM');
ylabel('Torque (Nm)');
hold on;
contourf(rpm_engine_data, torque_engine_data, bsfc_engine_data);
clim([200, 1000]);
ylim([0,170]);
xlim([500, 6500]);
hold on;
plot(rpm_optimum_shift,torque_optimum_shift,'y-', Linewidth=1.5);
hold on;
legend('Torque Max', 'BSFC (g/kWhr)','Optimum shift line', 'Maximum Power');
title('BSFC (g/kWhr) Map');
hold off;

%Simulink
open_system("AuE6610_Project_GearMap");
sim("AuE6610_Project_GearMap");
set_param('AuE6610_Project_GearMap/Driver/Manual Switch', 'sw', '1');
set_param('AuE6610_Project_GearMap/engine/To Workspace1','Commented','off');
set_param('AuE6610_Project_GearMap/engine/To Workspace2','Commented','off');
set_param('AuE6610_Project_GearMap/engine/To Workspace3','Commented','on');
set_param('AuE6610_Project_GearMap/engine/To Workspace4','Commented','on');
sim("AuE6610_Project_GearMap");
close_system("AuE6610_Project_GearMap",0);

% Plotting BSFC contour
figure;
yyaxis right;
plot(rpm_engine_data(1,:), power_engine_data(end,:)/1000, 'g--', Linewidth=2);
ylabel('Power (kW)');
hold on;
yyaxis left;
plot(rpm_engine_data(1,:), torque_engine_data(end,:),'r--', Linewidth=2);
xlabel('RPM');
ylabel('Torque (Nm)');
hold on;
contourf(rpm_engine_data, torque_engine_data, bsfc_engine_data);
clim([200, 1000]);
ylim([0,150]);
xlim([500, 6500]);
hold on;
plot(rpm_optimum_shift,torque_optimum_shift,'y-', Linewidth=1.5);
hold on;
scatter(rpm_drive_cycle,torque_drive_cycle, 10, 'filled', 'red');
hold on;
scatter(rpm_drive_cycle_wot,torque_drive_cycle_wot, 10, 'filled', 'black');
legend('Torque Max', 'BSFC (g/kWhr)','Optimum shift line', 'Operating Points_FTP','Operating Points WOT', 'Maximum Power');
title('BSFC (g/kWhr) Map');
hold off;

peak_power = max((pi*rpm_drive_cycle/30) .* torque_drive_cycle)/1000;       % Peak power at crankshaft in kW
fprintf('The peak power at crankshaft for FTP drivecycle is %f kW \n', peak_power)

% Calculating the MPG fuel economy
total_fuel_consumed = fuel_drive_cycle(end);
total_distance = 0.000621371*dist(end);
mpg = (3.78541*0.74*total_distance)/total_fuel_consumed;
fprintf('The MPG of the vehicle for FTP drivecycle is %.3f \n', mpg);

% Turbocharged engine

% Given data
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
bsfc_data = load("Engine_Vol_Therm_Eff.mat");
therm_eff = bsfc_data.Thermo_eff;
therm_eff_rpm = bsfc_data.Thermo_eff_RPM;
therm_eff_mass = bsfc_data.Thermo_eff_cyl_air_in_kg;
rpm_turbo = [1800 2800 3800 4800 5800 6800];
mass_per_cycle_turbo = [0.000615 0.000885 0.00106 0.00111 0.00116 0.00117];
boost_pressure = [24131.7 68947.6 89631.8 89631.8 89631.8 89631.8];
pmep_turbo = [-5000 -25000 -23000 -9000 12000 32000];
rpm_turbo_continue = 500:100:6800;
mass_per_cycle_turbo = interp1(rpm_turbo,mass_per_cycle_turbo,rpm_turbo_continue,"linear","extrap");
boost_pressure_continue = interp1(rpm_turbo, boost_pressure, rpm_turbo_continue,"linear","extrap");
pmep_turbo = interp1(rpm_turbo,pmep_turbo,rpm_turbo_continue,"linear","extrap");
[rpm_plot_turbo,x] = meshgrid(rpm_turbo_continue,mass_per_cycle_turbo);

% Data generation for plot
torque_turbo_data = zeros(length(mass_per_cycle_turbo),length(rpm_turbo_continue));
power_turbo_data = zeros(length(mass_per_cycle_turbo),length(rpm_turbo_continue));
bsfc_turbo_data = zeros(length(mass_per_cycle_turbo),length(rpm_turbo_continue));
eta_conversion_turbo_data = zeros(length(mass_per_cycle_turbo),length(rpm_turbo_continue));
fuel_mass_per_cycle_turbo_data = zeros(length(mass_per_cycle_turbo),length(rpm_turbo_continue));
imep_gross_engine_data = zeros(length(mass_per_cycle_turbo),length(rpm_turbo_continue));
bmep_turbo_data = zeros(length(mass_per_cycle_turbo),length(rpm_turbo_continue));
therm_eff_engine_data = zeros(length(mass_per_cycle_turbo),length(rpm_turbo_continue));
for i = 1 : length(rpm_turbo_continue)
    for j = 1 : length(mass_per_cycle_turbo)
        mass_flow_rate_turbo = (mass_per_cycle_turbo(j) * (rpm_turbo_continue(i) / (2 * 60)));
        fuel_mass_per_cycle_turbo = mass_per_cycle_turbo(j) / AFR_stoich;
        fuel_mass_per_cycle_turbo_data(j,i) = fuel_mass_per_cycle_turbo;
        therm_eff_engine = interp2(therm_eff_rpm, therm_eff_mass, therm_eff, rpm_turbo_continue(i), mass_per_cycle_turbo(j));
        therm_eff_engine_data(j,i) = therm_eff_engine;
        fuel_mass_flow_rate_turbo = mass_flow_rate_turbo / AFR_stoich;
        work_engine = therm_eff_engine * fuel_mass_per_cycle_turbo * calorific_value;
        imep_gross_engine = work_engine / volume_displaced;
        imep_gross_engine_data(j,i) = imep_gross_engine;
        exhaust_pressure_engine = 97708 + (70600 * 4 * (15.6/14.6)*mass_flow_rate_turbo) - (38260 * 4 * (((15.6/14.6)*mass_flow_rate_turbo)^2));
        imep_pump_turbo = (boost_pressure_continue(j) - exhaust_pressure_engine);
        fmep_turbo = -((0.97 + (0.15 * (rpm_turbo_continue(i)/(1000))) + (0.05 * ((rpm_turbo_continue(i)/(1000))^2))) * 100000);
        bmep_turbo = imep_gross_engine + pmep_turbo(j) + fmep_turbo;
        bmep_turbo_data(j,i) = bmep_turbo;
        bsfc_turbo = fuel_mass_per_cycle_turbo / (bmep_turbo * volume_displaced);

        % Skip unrealistic points
        if bmep_turbo <= 0 || isnan(bmep_turbo)
            bsfc_turbo = NaN;
            power_turbo = NaN;
        else
            bsfc_turbo = min(bsfc_turbo, 2000 / (1000000 * 3600)); % cap at 1400 g/kWh
            power_turbo = (n_cylinder * fuel_mass_flow_rate_turbo) / bsfc_turbo;
        end

        bsfc_turbo_data(j, i) = bsfc_turbo * 1000000 * 3600;
        torque_turbo = power_turbo / (rpm_turbo_continue(i) * ((2 * pi) / 60));
        torque_turbo_data(j, i) = torque_turbo;
        power_turbo_data(j, i) = power_turbo;
        eta_conversion = power_turbo / (n_cylinder * fuel_mass_flow_rate_turbo * calorific_value);
        eta_conversion_turbo_data(j,i) = eta_conversion;
    end
end

[rpm_q, torque_q] = meshgrid( ...
    linspace(min(rpm_turbo_continue), max(rpm_turbo_continue), 200), ...
    linspace(min(torque_turbo_data(:)), max(torque_turbo_data(:)), 200) );
bsfc_interp = griddata(rpm_plot_turbo, torque_turbo_data, bsfc_turbo_data, rpm_q, torque_q);

% Plotting the results
figure;
yyaxis right;
plot(rpm_turbo_continue, power_turbo_data(end,:)/1000, 'r--', Linewidth=1.5);
ylabel('Power (kW)');
hold on;
yyaxis left;
plot(rpm_turbo_continue, torque_turbo_data(end,:),'k--', Linewidth=1.5);
xlabel('RPM');
ylabel('Torque (Nm)');
hold on;
contourf(rpm_q, torque_q, bsfc_interp,10);
colorbar;
clim([200, 2000]);
ylim([0,350]);
xlim([500, 6800]);
legend('Torque', 'BSFC (g/kWhr)', 'Power');
title('BSFC (g/kWhr) Map');
hold off;

figure;
plot(rpm_turbo_continue, torque_turbo_data(end,:), Linewidth=1.2);
hold on;
contour(rpm_plot_turbo, torque_turbo_data, eta_conversion_turbo_data, 'ShowText','on');
ylabel('Torque (Nm)');