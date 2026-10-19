function export_diagrams()
% EXPORT_DIAGRAMS  Save pictures of the model and its main subsystems to docs/.
root = fileparts(fileparts(mfilename('fullpath')));
mdl  = 'hybrid_pv_wind_islanding';
load_system(fullfile(root, [mdl '.slx']));
out = fullfile(root, 'docs');
if ~exist(out, 'dir'), mkdir(out); end
parts = {'', 'model_top'; ...
         '/Wind_Subsystem', 'wind_subsystem'; ...
         '/DC-DC Boost Converter with MPPT', 'pv_boost_mppt'; ...
         '/Inverter Control Logic', 'inverter_control'; ...
         '/Passive Anti-Islanding Protection', 'passive_protection'; ...
         '/Second inverter control', 'second_inverter'; ...
         '/Sensor noise', 'sensor_noise'; ...
         '/Machine-learning islanding detector', 'ml_detector_block'};
for k = 1:size(parts, 1)
    print(['-s' mdl parts{k,1}], '-dpng', '-r120', fullfile(out, [parts{k,2} '.png']));
end
fprintf('Saved %d diagrams to %s\n', size(parts, 1), out);

% The real feeder (BUILD_FEEDER_MODEL): its lines and loads sit at the top
% level, right of the unit, so the top level is cropped to that part.
fdr = 'hybrid_pv_wind_feeder';
if exist(fullfile(root, [fdr '.slx']), 'file')
    load_system(fullfile(root, [fdr '.slx']));
    f = fullfile(out, 'feeder_model.png');
    print(['-s' fdr], '-dpng', '-r150', f);
    img = imread(f);
    imwrite(img(:, round(0.4925*size(img, 2)):end, :), f);
    print(['-s' fdr '/Second inverter control'], '-dpng', '-r150', fullfile(out, 'feeder_second_inverter.png'));
    close_system(fdr, 0);
    fprintf('Saved the feeder diagrams to %s\n', out);
end
end
