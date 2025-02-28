% pop_fileio() - import data files into EEGLAB using FileIO 
%
% Usage:
%   >> OUTEEG = pop_fileio; % pop up window
%   >> OUTEEG = pop_fileio( filename );
%   >> OUTEEG = pop_fileio( header, dat, evt );
%
% Inputs:
%   filename - [string] file name
%   header   - fieldtrip data header 
%   data     - fieldtrip raw data
%   evt      - fieldtrip event structure
%
% Optional inputs:
%   'channels'   - [integer array] list of channel indices
%   'samples'    - [min max] sample point limits for importing data
%   'trials'     - [min max] trial's limit for importing data
%   'dataformat' - [string] data format. Default is automatic. Available
%                  choices are available in ft_read_data
%   'memorymapped' - ['on'|'off'] import memory mapped file (useful if 
%                  encountering memory errors). Default is 'off'.
%
% Outputs:
%   OUTEEG   - EEGLAB data structure
%
% Author: Arnaud Delorme, SCCN, INC, UCSD, 2008-
%
% Note: FILEIO toolbox must be installed. 

% Copyright (C) 2008 Arnaud Delorme, SCCN, INC, UCSD, arno@salk.edu
%
% This file is part of EEGLAB, see http://www.eeglab.org
% for the documentation and details.
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are met:
%
% 1. Redistributions of source code must retain the above copyright notice,
% this list of conditions and the following disclaimer.
%
% 2. Redistributions in binary form must reproduce the above copyright notice,
% this list of conditions and the following disclaimer in the documentation
% and/or other materials provided with the distribution.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
% THE POSSIBILITY OF SUCH DAMAGE.

function [EEG, command] = pop_fileio(filename, varargin)
EEG = [];
command = '';

if exist('plugin_askinstall')
    if ~plugin_askinstall('Fileio', 'ft_read_data'), return; end
end

alldata = [];
event   = [];
if nargin < 1
	% ask user
    ButtonName = questdlg2('Do you want to import a file or a folder?', ...
                           'FILE-IO import', ...
                           'Folder', 'File', 'File');
    if strcmpi(ButtonName, 'file')
        [filename, filepath] = uigetfile('*.*', 'Choose a file or header file -- pop_fileio()'); 
        drawnow;
        if filename(1) == 0 return; end
        filename = fullfile(filepath, filename);
    else
        filename = uigetdir('*.*', 'Choose a folder -- pop_fileio()'); 
        drawnow;
        if filename(1) == 0 return; end
    end
    
    % open file to get infos
    % ----------------------
    formats = { 'auto' '4d' '4d_pdf'  '4d_m4d'  '4d_xyz' 'bci2000_dat' 'besa_avr' 'besa_swf' 'biosemi_bdf'  'bham_bdf' 'biosemi_old' 'biosig' ...
        'gdf' 'brainvision_eeg' 'brainvision_dat' 'brainvision_seg' 'ced_son' 'deymed_ini' 'deymed_dat' 'emotiv_mat' 'gtec_mat' ...
        'itab_raw' 'combined_ds' 'ctf_ds'  'ctf_meg4'  'ctf_res4' 'ctf_old' 'read_ctf_meg4' 'ctf_read_meg4' 'ctf_shm' 'dataq_wdq' ...
        'eeglab_set'  'eeglab_erp'  'spmeeg_mat' 'ced_spike6mat' 'edf' 'eep_avr' 'eep_cnt' 'eyelink_asc' 'fcdc_buffer' 'fcdc_buffer_offline' ...
        'fcdc_matbin'  'fcdc_mysql' 'egi_egia' 'egi_egis' 'egi_sbin' 'egi_mff_v1' 'egi_mff_v2' 'micromed_trc' 'mpi_ds'  'mpi_dap' ...
        'netmeg' 'neuralynx_dma' 'neuralynx_sdma' 'neuralynx_ncs' 'neuralynx_nse' 'neuralynx_nte' 'neuralynx_ttl'  'neuralynx_tsl' ...
        'neuralynx_tsh' 'neuralynx_bin' 'neuralynx_ds' 'neuralynx_cds' 'nexstim_nxe' 'ns_avg' 'ns_cnt' 'ns_cnt16'  'ns_cnt32' 'ns_eeg' ...
        'neuromag_fif' 'neuromag_mne' 'neuromag_mex' 'neuroprax_eeg' 'plexon_ds' 'plexon_ddt' 'read_nex_data' 'read_plexon_nex' 'plexon_nex' ...
        'plexon_plx' 'yokogawa_ave'  'yokogawa_con'  'yokogawa_raw' 'nmc_archive_k' 'neuroshare' 'bucn_nirs' 'riff_wave' 'neurosim_ds' ...
        'neurosim_signals' 'neurosim_evolution'  'neurosim_spikes' 'manscan_mb2'  'manscan_mbi' 'neuroscope_bin' };
    
    eeglab_options;
    mmoval = option_memmapdata;
    disp('Reading data file header...');
    dat = ft_read_header(filename);
    valueFormat = 1;
    if strcmpi(filename(end-2:end), 'mff')
        valueFormat = 48;
    end
    uilist   = { { 'style' 'text' 'String' 'Channel list (default all):' } ...
                 { 'style' 'edit' 'string' '' } ...
                 { 'style' 'text' 'String' [ 'Data range (in sample points) (default all [1 ' int2str(dat.nSamples) '])' ] } ...
                 { 'style' 'edit' 'string' '' } ...
                 };
    geom = { [3 1.5] [3 1.5] };
    if dat.nTrials > 1
        uilist{end+1} = { 'style' 'text' 'String' [ 'Trial range (default all [1 ' int2str(dat.nTrials) '])' ] };
        uilist{end+1} = { 'style' 'edit' 'string' '' };
        geom = { geom{:} [3 1.5] };
    end
    uilist   = { uilist{:} ...
                 { 'style' 'text' 'String' 'Data format' } ...
                 { 'style' 'popupmenu' 'string' formats 'value' valueFormat 'listboxtop' valueFormat } ...
                 { 'style' 'checkbox' 'String' 'Import as memory mapped file (use in case of out of memory) - beta' 'value' option_memmapdata } };
    geom = { geom{:}  [3 1.5] [1] };
    
    result = inputgui( geom, uilist, 'pophelp(''pop_fileio'')', 'Load data using FILE-IO -- pop_fileio()');
    if length(result) == 0 return; end
    if dat.nTrials <= 1
        result = { result{1:2} [] result{3:end} };
    end
    options = {};
    if length(result) == 3, result = { result{1:2} '' result{3}}; end
    if ~isempty(result{1}), options = { options{:} 'channels' eval( [ '[' result{1} ']' ] ) }; end
    if ~isempty(result{2}), options = { options{:} 'samples'  eval( [ '[' result{2} ']' ] ) }; end
    if ~isempty(result{3}), options = { options{:} 'trials'   eval( [ '[' result{3} ']' ] ) }; end
    if ~isempty(result{4}), options = { options{:} 'dataformat' formats{result{4}} }; end
    if result{5}, options = { options{:} 'memorymapped' fastif(result{5}, 'on', 'off') }; end
else
    if ~isstruct(filename)
        dat = ft_read_header(filename);
        options = varargin;
    else
        dat = filename;
        filename = '';
        alldata = varargin{1};
        options = {};
        if nargin >= 3
             event = varargin{2};
        end
    end
end

% decode input parameters
% -----------------------
g = struct(options{:});
if ~isfield(g, 'samples'), g.samples = []; end
if ~isfield(g, 'trials'), g.trials = []; end
if ~isfield(g, 'channels'), g.channels = []; end
if ~isfield(g, 'dataformat'), g.dataformat = 'auto'; end
if ~isfield(g, 'memorymapped'), g.memorymapped = 'off'; end

% import data
% -----------
EEG = eeg_emptyset;
fprintf('Reading data ...\n');
dataopts = {};
% In case of FIF files convert EEG channel units to uV in FT options
[trash1, trash2, filext] = fileparts(filename); clear trash1 trash2;
if strcmpi(filext,'.fif')
    eegchanindx = find(strcmpi(dat.chantype,'eeg'));
    if ~isempty(eegchanindx) && isfield (dat,'chanunit')
        if ~all(strcmpi(dat.chanunit(eegchanindx),'uv'))
            fprintf('Forcing EEG channel units to ''uV'' ...... \n');
            chanunitval = dat.chanunit;
            chanunitval(eegchanindx) = {'uV'};
            dataopts = { dataopts{:} 'chanunit', chanunitval};
        else
            fprintf('EEG channel units already in ''uV'' \n');
        end  
    end
end
if ~isempty(g.samples ), dataopts = { dataopts{:} 'begsample', g.samples(1), 'endsample', g.samples(2)}; end
if ~isempty(g.trials  ), dataopts = { dataopts{:} 'begtrial', g.trials(1), 'endtrial', g.trials(2)}; end
if ~strcmpi(g.dataformat, 'auto'), dataopts = { dataopts{:} 'dataformat' g.dataformat }; end
if strcmpi(g.memorymapped, 'off') || ~isempty(alldata)
    if ~isempty(g.channels), dataopts = { dataopts{:} 'chanindx', g.channels }; end
    if isempty(alldata)
        alldata = ft_read_data(filename, 'header', dat, dataopts{:});
    end
else
    % read memory mapped file
    g.datadims = [ dat.nChans dat.nSamples dat.nTrials ];
    disp('Importing as memory mapped array, this may take a while...');
    if isempty(g.channels), g.channels = [1:g.datadims(1)]; end
    if ~isempty(g.samples ), g.datadims(2) = g.samples(2) - g.samples(1); end
    if ~isempty(g.trials  ), g.datadims(3) = g.trials(2)  - g.trials(1); end
    g.datadims(1) = length(g.channels);
    alldata = mmo([], g.datadims);
    for ic = 1:length(g.channels)
        alldata(ic,:,:) = ft_read_data(filename, 'header', dat, dataopts{:}, 'chanindx', g.channels(ic));
    end
end

% convert to seconds for sread
% ----------------------------
EEG.srate           = dat.Fs;
EEG.nbchan          = dat.nChans;
EEG.data            = alldata;
EEG.setname 		= '';
EEG.comments        = [ 'Original file: ' filename ];
EEG.xmin = -dat.nSamplesPre/EEG.srate; 
EEG.trials = dat.nTrials;
if size(alldata,3) > 1
    EEG.trials = size(alldata,3);
    EEG.pnts   = size(alldata,2);
else
    if dat.nTrials == 1
        EEG.pnts        = size(alldata,2);
    else
        EEG.pnts        = dat.nSamples;
    end
end
if isfield(dat, 'label') && ~isempty(dat.label)
    EEG.chanlocs = struct('labels', dat.label);
    % channel type
    if isfield(dat,'chantype')
        for ichan = 1:length(dat.chantype)
            EEG.chanlocs(ichan).type = dat.chantype{ichan};
        end
    end
    
    % START ----------- Extracting EEG channel location
    % Note: Currently for extensions where FT is able to generate valid 'labels' and 'elec' structure (e.g. FIF)
    %If more formats, add them below
    try
        if isfield(dat,'elec')
            eegchanindx = find(ft_chantype(dat, 'eeg') );
            for ichan = 1:length(eegchanindx)
                EEG = pop_chanedit(EEG,'changefield',{eegchanindx(ichan) 'X' dat.elec.chanpos(ichan,1) 'Y' dat.elec.chanpos(ichan,2) 'Z' dat.elec.chanpos(ichan,3) 'type' 'EEG'});
            end
            eegchanindx = find(ft_chantype(dat, 'pns') );
            for ichan = 1:length(eegchanindx)
                EEG = pop_chanedit(EEG,'changefield',{eegchanindx(ichan) 'X' dat.elec.chanpos(ichan,1) 'Y' dat.elec.chanpos(ichan,2) 'Z' dat.elec.chanpos(ichan,3) 'type' 'PNS'});
            end
        end
    catch
        fprintf('pop_fileio: Unable to import channel location\n');
    end
    try
        if isfield(dat,'grad')
            eegchanindx = find(ft_chantype(dat, 'refmag') | ft_chantype(dat, 'gradmag') );
            for ichan = 1:length(eegchanindx)
                chanType = 'EEG';
                EEG = pop_chanedit(EEG,'changefield',{eegchanindx(ichan) 'X' dat.grad.chanpos(ichan,1) 'Y' dat.grad.chanpos(ichan,2) 'Z' dat.grad.chanpos(ichan,3) });
            end
        end
    catch
        fprintf('pop_fileio: Unable to import channel location\n');
    end
    EEG.chanlocs   = convertlocs(EEG.chanlocs,'cart2all');
    EEG.urchanlocs = EEG.chanlocs;
    % END ----------- Extracting EEG channel location
end

% extract events
% --------------
disp('Reading events...');
if isempty(event)
    try
        event = ft_read_event(filename, dataopts{:});
    catch
        disp(lasterr); 
        event = []; 
    end
end
if ~isempty(event)
    subsample = 0;
    
    if ~isempty(g.samples), subsample = g.samples(1); end
    
    EEG.event = event;
    for index = 1:length(event)
        offset = fastif(isempty(event(index).offset), 0, event(index).offset);
        EEG.event(index).type     = event(index).value;
        EEG.event(index).value    = event(index).type;
        EEG.event(index).latency  = event(index).sample+offset+subsample;
        EEG.event(index).duration = event(index).duration;
        if EEG.trials > 1
            EEG.event(index).epoch = ceil(EEG.event(index).latency/EEG.pnts);        
        end
    end
    EEG.event = rmfield(EEG.event, 'sample');
    EEG.event = rmfield(EEG.event, 'value');
    EEG.event = rmfield(EEG.event, 'offset');
    
    if exist('eeg_checkset')
        EEG = eeg_checkset(EEG, 'eventconsistency');
    end
else
    disp('Warning: no event found. Events might be embedded in a data channel.');
    disp('         To extract events, use menu File > Import Event Info > From data channel');
end

% convert data to single if necessary
% -----------------------------------
if exist('eeg_checkset')
    EEG = eeg_checkset(EEG,'makeur');   % Make EEG.urevent field
end

% history
% -------
if ischar(filename)
    if isempty(options)
        command = sprintf('EEG = pop_fileio(''%s'');', filename);
    else
        command = sprintf('EEG = pop_fileio(''%s'', %s);', filename, vararg2str(options));
    end
end
