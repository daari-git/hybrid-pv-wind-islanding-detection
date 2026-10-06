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
         '/Passive Anti-Islanding Protection', 'passive_protection'};
for k = 1:size(parts, 1)
    print(['-s' mdl parts{k,1}], '-dpng', '-r120', fullfile(out, [parts{k,2} '.png']));
end
fprintf('Saved %d diagrams to %s\n', size(parts, 1), out);
end
