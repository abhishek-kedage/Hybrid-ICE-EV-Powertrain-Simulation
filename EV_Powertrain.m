% Extracting data from excel
% drive_cycle_data = readtable('Drive_Cycle/track.xlsx');
% velocity_profile = [(1:length(drive_cycle_data.Car_Velocity_mps))' drive_cycle_data.Car_Velocity_mps];
% plot(velocity_profile(:,2));

clc;
clear;
idle_rpm = 1;                         % Idle speed (RPM)
redline_rpm = 11000;                     % Maximum speed (RPM)
rpm = (idle_rpm:100:redline_rpm);       % RPM array

% Transmission and gearing
gear = 1.5;  % Gear ratios
gear_no = 1;                 % Gear numbers
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
gravity = 9.81;

% Load drive cycle and engine data
drive_cycle_data = readtable("Drive_Cycle/track.xlsx");
drive_cycle = [(1:length(drive_cycle_data.Car_Velocity_mps))' drive_cycle_data.Car_Velocity_mps];
acc_profile = gradient(drive_cycle_data.Car_Velocity_mps, (1:length(drive_cycle_data.Car_Velocity_mps))');
aero_drag = 0.5 * drag_coefficient * area_frontal * rho_air * (drive_cycle_data.Car_Velocity_mps).^2;               % Drag force
rolling_force = rolling_resistance_coefficient * curb_weight * gravity;                    % Rolling resistance force
acc_force_profile = curb_weight * acc_profile;
engine_force_profile = zeros(size(acc_force_profile));                  % Force provided by engine
brake_force_profile = zeros(size(acc_force_profile)); 

for i = 1 : length(acc_force_profile)
    if acc_force_profile(i) >= 0 % engine is giving power only if acceleration is zero or positive
        if drive_cycle_data.Car_Velocity_mps(i) > 0 % If vehicle is stopped at red light engine is not providing powers to wheel
            engine_force_profile(i) = acc_force_profile(i) + aero_drag(i) + rolling_force;
        end
    else
        if (acc_force_profile(i) + rolling_force + aero_drag(i)) < 0
            brake_force_profile(i) = -(acc_force_profile(i) + rolling_force + aero_drag(i)); % Brake force contributing to negative acceleration
        else
            engine_force_profile(i) = acc_force_profile(i) + rolling_force + aero_drag(i);   % Cases where engine is contributing but vehicle is decelerating
        end
    end
end
engine_power_profile = engine_force_profile .* drive_cycle_data.Car_Velocity_mps; 
total_energy_consumed = trapz((1:length(drive_cycle_data.Car_Velocity_mps))', engine_power_profile);


load battery_data.mat
load motor_data.mat;
time_in_s = (0:length(drive_cycle_data.Car_Velocity_mps))';
time_soc = (0:300:length(drive_cycle_data.Car_Velocity_mps))';
batt.num_cells = 1800;    % total number of cells
batt.num_cell_series = 90;  % number of cells in series
batt.num_module_parallel = 20;   % number of modules in parallel
batt.volt_nom = 3.6;    % nominal voltage in V
batt.volt_max = 3.9;    % max voltage in V
batt.volt_min = 3.3;    % min voltage in V
batt.curr_chg_max = -150;  % max charging current in A
batt.curr_dis_max = 200;     % max discharging current in A
batt.soc_max = 0.95;     % max SoC
batt.soc_min = 0.28;     % min SoC
batt.soc_init = 0.90;     % initial SoC
batt.col_eff.temperature = [0,25,41]; % temperature vector for coulombic efficiency in C
batt.col_eff.col_eff = [0.9680,0.9900,0.9920];  % coulombic efficiency vector 
batt.mass_per_cell = 0.0126; % mass per cell in kg
batt.cp_cell = 795; % heat capacity of battery cell in J/(kg K)
batt.cp_coolant = 4500; % heat capacity of coolant in J/(kg K)
batt.heat_trans_coeff = 50; % heat transfer coefficient in J/(m^2 K)
batt.eff_area = 8;  % heat transfer effective area in m^2
batt.amb_temp = 25;    % ambient temperature in K
batt.coolant_temp_in = 25; % coolant intake temperature in C
batt.coolant_mass = 20;  % total mass of coolant in the cooling system
batt.coolant_flow_rate = 1.2;


% Simulink
fprintf('Running Simulink simulation...\n');
%open_system("AuE6610_Project_EV");
sim("AuE6610_Project_EV.slx");
% set_param('AuE6610_Project_EV/Driver/Manual Switch', 'sw', '1');
% set_param('AuE6610_Project_EV/engine/To Workspace1', 'Commented', 'off');
% set_param('AuE6610_Project_EV/engine/To Workspace2', 'Commented', 'off');
% set_param('AuE6610_Project_EV/engine/To Workspace3', 'Commented', 'on');
% set_param('AuE6610_Project_EV/engine/To Workspace4', 'Commented', 'on');
% sim("AuE6610_Project_EV");
%close_system("AuE6610_Project_EV", 0);
fprintf('Simulink simulation complete.\n\n');



% Efficiency calculation
elec_power = mot.efficiency.elec_power;
efficiency = zeros(size(elec_power));
rpm_calc = mot.efficiency.RPM;
for i = 1:length(rpm_calc)
    for j = 1:length(mot.efficiency.Torque)
        if mot.efficiency.Torque(j) >= 0
            efficiency(i,j) = 100 * (rpm_calc(i)*(pi/30)*mot.efficiency.Torque(j) / elec_power(i,j));
        elseif mot.efficiency.Torque(j) < 0
            efficiency(i,j) = 100 * ((rpm_calc(i)*(pi/30)*mot.efficiency.Torque(j)) / elec_power(i,j));
        end
    end
end

cols_src = 42:81;
cols_dst = 40:-1:1;
efficiency(:, cols_dst) = efficiency(:, cols_src);

[torque_eff,rpm_eff] = meshgrid(mot.efficiency.Torque,rpm_calc);

% Plotting
figure;
plot(time_in_s, pack_terminal, LineWidth=1.2);
xlabel('Time (s)');
ylabel('Battery Terminal Voltage (V)');
title('Battery Terminal Voltage vs Time');
grid on;

figure;
plot(time_in_s, pack_ocv, LineWidth=1.2);
xlabel('Time (s)');
ylabel('Battery OCV (V)');
title('Battery OCV vs Time');
grid on;

figure;
plot(time_in_s, soc*100, LineWidth=1.2);
xlabel('Time (s)');
ylabel('SOC (%)');
title('SOC vs Time');
grid on;

figure;
plot(time_in_s, battery_temp, LineWidth=1.2);
grid on;
hold on
plot(time_in_s, coolant_temp_out, LineWidth=1.2);
xlabel('Time (s)');
ylabel('Temperature (Degree Celcius)');
title('Battery and Coolant Temperature vs Time');
grid on;
legend('Battery Pack Temperature','Coolant Temperature')
hold off;

figure;
contourf(rpm_eff,torque_eff,efficiency,30);
clim([0,100]);
colorbar;
hold on;
scatter(operating_mot_rpm,operating_mot_torque,10,"filled")
hold on;
plot(abs(mot.max_torque.RPM),mot.max_torque.Torque, LineWidth=1.8);
xlabel("RPM");
ylabel("Torque (Nm)");
legend('Motor Efficiency','Operating Points','Max Torque')
title("Motor Efficiency and Operating Points");

grid on;
hold off;

% Calculate peak power and fuel economy
peak_power = max((pi/30)*operating_mot_rpm .* operating_mot_torque) / 1000;
fprintf('The peak power at motor for this drivecycle is %.2f kW\n', peak_power);

dod = ones(length(soc_profile), 1);
dod = dod - soc_profile;
c = rainflow(dod,time_soc);

% Cycle calculation
cycles = interp1(batt.cyc_life.DOD, batt.cyc_life.cyc_life, c(:,2));
inverse = 0;
for i = 1:length(c(:,1))
    inverse = inverse + (c(i,1)*(1/cycles(i)));
end
life = 1/inverse;
life_miles = life * 37;
fprintf('Battery life in terms of miles is %.3f miles \n', life_miles);


delta_soc = batt.soc_init - soc(end);
mil_per_soc = 37 / delta_soc;
range = mil_per_soc * (batt.soc_max-batt.soc_min);
fprintf('Range of vehicle in miles is %.3f miles \n', range);