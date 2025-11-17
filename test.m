%% BVH exporter -> LaFAN1-compatible 69-channel BVH (slowed 6x)
matFile    = 'test.mat';  % path to your .mat table
outputBVH  = '/home/stevenh/Documents/output_motion.bvh';
frameTime  = 0.005;       % seconds per frame
slowFactor = 6;           % slowdown factor

%% Load table
S = load(matFile);
if isfield(S,'steadyspeed')
    T = S.steadyspeed;
else
    error('MAT file does not contain table "steadyspeed".');
end

% Remove optional header column
if any(strcmp(T.Properties.VariableNames,'Header'))
    T.Header = [];
end

%% --- Joint list and offsets ---
jointOrder = { ...
    'Hips', ...
    'LeftUpLeg','LeftLeg','LeftFoot','LeftToe', ...
    'RightUpLeg','RightLeg','RightFoot','RightToe', ...
    'Spine','Spine1','Spine2','Neck','Head', ...
    'LeftShoulder','LeftArm','LeftForeArm','LeftHand', ...
    'RightShoulder','RightArm','RightForeArm','RightHand' ...
};

% offsets (example values)
offsets.Hips         = [586.84 97.3 -848.3];
offsets.LeftUpLeg    = [0.103456 1.857840 10.548509];
offsets.LeftLeg      = [43.500000 -0.000042 0.000010];
offsets.LeftFoot     = [42.372192 0.000019 0.000000];
offsets.LeftToe      = [17.299999 -0.000000 0.000003];
offsets.RightUpLeg   = [0.103456 1.857823 -10.548508];
offsets.RightLeg     = [43.500042 -0.000027 0.000004];
offsets.RightFoot    = [42.372261 0.000000 0.000010];
offsets.RightToe     = [17.299994 -0.000006 0.000017];
offsets.Spine        = [6.901967 -2.603732 -0.000003];
offsets.Spine1       = [12.588099 0.000010 0.000008];
offsets.Spine2       = [12.343201 -0.000018 -0.000005];
offsets.Neck         = [25.832890 0.000023 0.000007];
offsets.Head         = [11.766609 -0.000008 -0.000006];
offsets.LeftShoulder = [19.745909 -1.480347 6.000101];
offsets.LeftArm      = [11.284133 0.000018 -0.000020];
offsets.LeftForeArm  = [33.000050 -0.000013 0.000019];
offsets.LeftHand     = [25.200005 0.000032 0.000011];
offsets.RightShoulder= [19.746101 -1.480358 -6.000078];
offsets.RightArm     = [11.284140 -0.000000 -0.000001];
offsets.RightForeArm = [33.000103 0.000016 -0.000001];
offsets.RightHand    = [25.199762 0.000123 0.000432];

%% --- Build BVH file ---
fid = fopen(outputBVH,'wt');
if fid == -1
    error('Could not open %s for writing.', outputBVH);
end

fprintf(fid,'HIERARCHY\n');
fprintf(fid,'ROOT Hips\n{\n');
fprintf(fid,'\tOFFSET %.6f %.6f %.6f\n', offsets.Hips);
fprintf(fid,'\tCHANNELS 6 Xposition Yposition Zposition Zrotation Yrotation Xrotation\n');
% --- left/right legs, spine, arms --- (use your previous nested fprintf structure here)
% [omitted for brevity; reuse your HIERARCHY fprintf code from above]
% Make sure to include all joints in correct BVH format
fprintf(fid,'}\n');

%% --- Motion header ---
numOrigFrames = height(T);
numFrames = numOrigFrames * slowFactor;
fprintf(fid,'MOTION\n');
fprintf(fid,'Frames: %d\n', numFrames);
fprintf(fid,'Frame Time: %.6f\n', frameTime);

%% --- Extract original 31:69 columns as numeric array ---
origCols = 31:69;
numRotCols = numel(origCols);
originalFrames = zeros(numOrigFrames, numRotCols);

for c = 1:numRotCols
    varName = sprintf('Var%d', origCols(c));
    if ismember(varName, T.Properties.VariableNames)
        val = T.(varName);
        % convert if cell
        if iscell(val)
            originalFrames(:, c) = cellfun(@str2double, val);
        else
            originalFrames(:, c) = val;
        end
    end
end

%% --- Interpolate for slower motion ---
tOrig = 1:numOrigFrames;
tSlow = linspace(1, numOrigFrames, numFrames);
slowFrames = zeros(numFrames, numRotCols);

for c = 1:numRotCols
    slowFrames(:, c) = interp1(tOrig, originalFrames(:, c), tSlow, 'linear');
end

%% --- Helper: get value or 0 if missing ---
hasCol = @(name) ismember(name, T.Properties.VariableNames);
getVal = @(tbl, name, idx) ( hasCol(name) * tbl{idx, name} + (~hasCol(name)) * 0 );

%% --- Write frames ---
for fi = 1:numFrames
    frame = zeros(1,69);

    % Hips positions
    frame(1) = getVal(T,'pelvis_tx',mod(fi-1,numOrigFrames)+1)*1000;
    frame(2) = getVal(T,'pelvis_ty',mod(fi-1,numOrigFrames)+1)*1000 - 880;
    frame(3) = getVal(T,'pelvis_tz',mod(fi-1,numOrigFrames)+1)*1000;

    % Hips rotations
    frame(4) = getVal(T,'pelvis_rotation',mod(fi-1,numOrigFrames)+1);
    frame(5) = getVal(T,'pelvis_list',mod(fi-1,numOrigFrames)+1);
    frame(6) = getVal(T,'pelvis_tilt',mod(fi-1,numOrigFrames)+1) + 90;

    % Other joints (LeftUpLeg, etc.) – keep your previous assignments here
    for j = 2:numel(jointOrder)
        nm = jointOrder{j};
        base = 6 + 3*(j-2) + 1;
        z = 0; y = 0; x = 0;
        switch nm
            case 'LeftUpLeg'
                x = getVal(T,'hip_rotation_l',mod(fi-1,numOrigFrames)+1)+180;
                y = getVal(T,'hip_adduction_l',mod(fi-1,numOrigFrames)+1);
                z = getVal(T,'hip_flexion_l',mod(fi-1,numOrigFrames)+1)+180;
            case 'LeftLeg'
                z = getVal(T,'knee_angle_l',mod(fi-1,numOrigFrames)+1);
            case 'RightUpLeg'
                x = getVal(T,'hip_rotation_r',mod(fi-1,numOrigFrames)+1)-180;
                y = getVal(T,'hip_adduction_r',mod(fi-1,numOrigFrames)+1);
                z = getVal(T,'hip_flexion_r',mod(fi-1,numOrigFrames)+1)+180;
            case 'RightLeg'
                z = getVal(T,'knee_angle_r',mod(fi-1,numOrigFrames)+1);
        end
        frame(base + 0) = z;
        frame(base + 1) = y;
        frame(base + 2) = x;
    end

    % Interpolated columns 31:69
    frame(31:69) = slowFrames(fi,:);

    % Write frame
    fprintf(fid, repmat('%f ', 1, numel(frame)), frame);
    fprintf(fid,'\n');
end

fclose(fid);
disp(['BVH saved to: ' outputBVH]);
