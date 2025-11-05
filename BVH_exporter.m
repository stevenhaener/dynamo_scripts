%% BVH Exporter using colNames from your table (steadyspeed)
% - Finds a table variable (prefers 'steadyspeed')
% - Builds colNames automatically from the table's VariableNames
% - Skips non-numeric 'Header' column
% - Puts pelvis channels first (if available), then the rest in original order
% - Converts radians -> degrees and writes a .bvh file

%% --- USER SETTINGS ---
matFile = 'test.mat';            % path to your .mat
outputBVH = 'output_motion.bvh'; % output name
frameTime = 0.005;               % seconds per frame
%% ------------------------

%% Load .mat and find the table (prefer 'steadyspeed' if present)
S = load(matFile);

tblName = 'steadyspeed';

T = S.(tblName);
fprintf('Using table: %s\n', tblName);
colNames = T.Properties.VariableNames;
disp('Original table columns:');
disp(colNames');

%% Remove textual 'Header' column if present
if ismember('Header', colNames)
    fprintf('Found Header column — it will be ignored.\n');
    colNames(strcmp(colNames,'Header')) = [];
end

%% Ensure numeric columns only (BVH needs numeric channels)
numericMask = false(size(colNames));
for i = 1:numel(colNames)
    v = T.(colNames{i});
    numericMask(i) = isnumeric(v);
end
if ~all(numericMask)
    nonNumeric = colNames(~numericMask);
    warning('The following columns are not numeric and will be ignored: %s', strjoin(nonNumeric, ', '));
    colNames = colNames(numericMask);
end

%% Reorder so pelvis channels are first (if available)
pelvisFields = {'pelvis_tx','pelvis_ty','pelvis_tz','pelvis_tilt','pelvis_list','pelvis_rotation'};
pelvisPresent = pelvisFields(ismember(pelvisFields, colNames));
% Keep their canonical order, then append the remaining columns in original order
remaining = setdiff(colNames, pelvisPresent, 'stable');
bvhOrder = [pelvisPresent, remaining];

% If pelvis translations are missing, warn (we will still write the BVH but root positions will be zeros)
if ~all(ismember({'pelvis_tx','pelvis_ty','pelvis_tz'}, bvhOrder))
    warning('One or more pelvis translation channels (pelvis_tx/pelvis_ty/pelvis_tz) are missing. Root positions will be set to 0 if not present.');
end

fprintf('BVH channel order (first 12 shown or all if fewer):\n');
disp(bvhOrder(1:min(numel(bvhOrder),12))');

%% Build a clean table in bvhOrder and convert radians->degrees
bvhTable = table();
for i = 1:numel(bvhOrder)
    name = bvhOrder{i};
    bvhTable.(name) = T.(name);  % use the numeric data (should be column vectors)
end

% Convert numeric columns from radians to degrees
vars = bvhTable.Properties.VariableNames;
for i = 1:numel(vars)
    if isnumeric(bvhTable.(vars{i}))
        bvhTable.(vars{i}) = bvhTable.(vars{i}) * 180 / pi;
    else
        error('Column %s is not numeric after selection — BVH requires numeric values.', vars{i});
    end
end

%% Simple BVH offsets (tweak as needed)
offsets.Hips = [0 0 0];
offsets.RightHip = [0 -10 0];
offsets.RightKnee = [0 -30 0];
offsets.RightAnkle = [0 -30 0];
offsets.LeftHip = [0 10 0];
offsets.LeftKnee = [0 30 0];
offsets.LeftAnkle = [0 30 0];
offsets.Spine = [0 0 10];

%% Open BVH and write hierarchy
fid = fopen(outputBVH, 'w');
if fid == -1
    error('Could not open %s for writing.', outputBVH);
end

fprintf(fid, 'HIERARCHY\n');
fprintf(fid, 'ROOT Hips\n{\n');
fprintf(fid, '\tOFFSET %.4f %.4f %.4f\n', offsets.Hips);
fprintf(fid, '\tCHANNELS 6 Xposition Yposition Zposition Xrotation Yrotation Zrotation\n');

% Right leg
fprintf(fid,'\tJOINT RightHip\n{\n');
fprintf(fid,'\t\tOFFSET %.4f %.4f %.4f\n', offsets.RightHip);
fprintf(fid,'\t\tCHANNELS 3 Xrotation Yrotation Zrotation\n');
fprintf(fid,'\t\tJOINT RightKnee\n{\n');
fprintf(fid,'\t\t\tOFFSET %.4f %.4f %.4f\n', offsets.RightKnee);
fprintf(fid,'\t\t\tCHANNELS 3 Xrotation Yrotation Zrotation\n');
fprintf(fid,'\t\t\tJOINT RightAnkle\n{\n');
fprintf(fid,'\t\t\t\tOFFSET %.4f %.4f %.4f\n', offsets.RightAnkle);
fprintf(fid,'\t\t\t\tCHANNELS 3 Xrotation Yrotation Zrotation\n');
fprintf(fid,'\t\t\t\tEnd Site\n\t\t\t\t{\n\t\t\t\t\tOFFSET 0 0 0\n\t\t\t\t}\n');
fprintf(fid,'\t\t\t}\n\t\t}\n\t}\n');

% Left leg
fprintf(fid,'\tJOINT LeftHip\n{\n');
fprintf(fid,'\t\tOFFSET %.4f %.4f %.4f\n', offsets.LeftHip);
fprintf(fid,'\t\tCHANNELS 3 Xrotation Yrotation Zrotation\n');
fprintf(fid,'\t\tJOINT LeftKnee\n{\n');
fprintf(fid,'\t\t\tOFFSET %.4f %.4f %.4f\n', offsets.LeftKnee);
fprintf(fid,'\t\t\tCHANNELS 3 Xrotation Yrotation Zrotation\n');
fprintf(fid,'\t\t\tJOINT LeftAnkle\n{\n');
fprintf(fid,'\t\t\t\tOFFSET %.4f %.4f %.4f\n', offsets.LeftAnkle);
fprintf(fid,'\t\t\t\tCHANNELS 3 Xrotation Yrotation Zrotation\n');
fprintf(fid,'\t\t\t\tEnd Site\n\t\t\t\t{\n\t\t\t\t\tOFFSET 0 0 0\n\t\t\t\t}\n');
fprintf(fid,'\t\t\t}\n\t\t}\n\t}\n');

% Spine/Lumbar
fprintf(fid,'\tJOINT Spine\n{\n');
fprintf(fid,'\t\tOFFSET %.4f %.4f %.4f\n', offsets.Spine);
fprintf(fid,'\t\tCHANNELS 3 Xrotation Yrotation Zrotation\n');
fprintf(fid,'\t\tEnd Site\n\t\t{\n\t\t\tOFFSET 0 0 0\n\t\t}\n');
fprintf(fid,'\t}\n');

fprintf(fid,'}\n'); % End ROOT

%% Motion section
numFrames = height(bvhTable);
fprintf(fid, 'MOTION\n');
fprintf(fid, 'Frames: %d\n', numFrames);
fprintf(fid, 'Frame Time: %.6f\n', frameTime);

% Write each frame in bvhOrder sequence
for f = 1:numFrames
    % If pelvis translations are missing, fill with zeros for root position
    rowVec = zeros(1, numel(bvhOrder));
    for c = 1:numel(bvhOrder)
        colName = bvhOrder{c};
        colData = bvhTable.(colName);
        rowVec(c) = colData(f);
    end
    fprintf(fid, '%f ', rowVec);
    fprintf(fid, '\n');
end

fclose(fid);
fprintf('BVH saved to: %s\n', outputBVH);
