%% BVH exporter -> LaFAN1-compatible 69-channel BVH
% Converts a MAT table (Vicon/OpenSim-like) into a BVH that matches the
% LaFAN1 22-joint skeleton (69 channels: 6 root + 21*3 rotations).
% Missing joints are zero-filled so GMR (--format lafan1) can load it.
%
% Usage: edit matFile/outputBVH/frameTime as needed and run.

%% --- USER SETTINGS ---
matFile    = 'test.mat';                % Path to your .mat file (table 'rows')
outputBVH  = '/home/stevenh/Documents/output_motion.bvh';       % Output BVH filename
frameTime  = 0.005;                     % seconds per frame
%% ----------------------

%% --- Load MAT file ---
S = load(matFile);
if isfield(S,'steadyspeed')
    T = S.steadyspeed;   % expected table
else
    error('MAT file does not contain table "rows".');
end

% Remove optional Header column
if any(strcmp(T.Properties.VariableNames,'Header'))
    T.Header = [];
end

%% --- Source columns you have (example from your exporter) ---
sourceCols = { ...
    'pelvis_tilt','pelvis_list','pelvis_rotation','pelvis_tx','pelvis_ty','pelvis_tz', ...
    'hip_flexion_r','hip_adduction_r','hip_rotation_r','knee_angle_r','ankle_angle_r','subtalar_angle_r','mtp_angle_r', ...
    'hip_flexion_l','hip_adduction_l','hip_rotation_l','knee_angle_l','ankle_angle_l','subtalar_angle_l','mtp_angle_l', ...
    'lumbar_extension','lumbar_bending','lumbar_rotation'};

% Keep only the columns that exist in table (stable order)
haveCols = intersect(sourceCols, T.Properties.VariableNames, 'stable');
T = T(:, haveCols);

%% --- Convert angles (radians->degrees) only for angle columns ---
% Define which of your columns represent angles (not translations)
angleCols = setdiff(haveCols, {'pelvis_tx','pelvis_ty','pelvis_tz'});


% for c = 1:numel(angleCols)
%     col = angleCols{c};
%     % only convert numeric columns
%     if isnumeric(T.(col))
%         T.(col) = T.(col) * 180/pi;
%     end
% end

%% --- Joint list (pre-order) to match example HIERARCHY ---
jointOrder = { ...
    'Hips', ...
      'LeftUpLeg','LeftLeg','LeftFoot','LeftToe', ...
      'RightUpLeg','RightLeg','RightFoot','RightToe', ...
      'Spine','Spine1','Spine2','Neck','Head', ...
      'LeftShoulder','LeftArm','LeftForeArm','LeftHand', ...
      'RightShoulder','RightArm','RightForeArm','RightHand' ...
    };

%% --- Offsets taken from your example HIERARCHY (keep as given) ---
%offsets.Hips         = [568.4 -848 -1500];
% offsets.Hips         = [0 0 0];

x_offset = getVal(T,'pelvis_tx',1)*1000;
y_offset = getVal(T,'pelvis_ty',1)*1000;
z_offset = getVal(T,'pelvis_tz',fi)*1000;

offsets.Hips         = [x_offset, y_offset, z_offset];

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

%% --- Open BVH for plain-text writing ---
fid = fopen(outputBVH,'wt');
if fid == -1
    error('Could not open %s for writing.', outputBVH);
end

%% --- Write HIERARCHY (structure & channel ordering as in example) ---
fprintf(fid,'HIERARCHY\n');
fprintf(fid,'ROOT Hips\n{\n');
fprintf(fid,'\tOFFSET %.6f %.6f %.6f\n', offsets.Hips);
fprintf(fid,'\tCHANNELS 6 Xposition Yposition Zposition Zrotation Yrotation Xrotation\n');

% Left leg chain
fprintf(fid,'\tJOINT LeftUpLeg\n\t{\n');
fprintf(fid,'\t\tOFFSET %.6f %.6f %.6f\n', offsets.LeftUpLeg);
fprintf(fid,'\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');
fprintf(fid,'\t\tJOINT LeftLeg\n\t\t{\n');
fprintf(fid,'\t\t\tOFFSET %.6f %.6f %.6f\n', offsets.LeftLeg);
fprintf(fid,'\t\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');
fprintf(fid,'\t\t\tJOINT LeftFoot\n\t\t\t{\n');
fprintf(fid,'\t\t\t\tOFFSET %.6f %.6f %.6f\n', offsets.LeftFoot);
fprintf(fid,'\t\t\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');
fprintf(fid,'\t\t\t\tJOINT LeftToe\n\t\t\t\t{\n');
fprintf(fid,'\t\t\t\t\tOFFSET %.6f %.6f %.6f\n', offsets.LeftToe);
fprintf(fid,'\t\t\t\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');
fprintf(fid,'\t\t\t\t\tEnd Site\n\t\t\t\t\t{\n\t\t\t\t\t\tOFFSET 0.000000 0.000000 0.000000\n\t\t\t\t\t}\n');
fprintf(fid,'\t\t\t\t}\n');
fprintf(fid,'\t\t\t}\n');
fprintf(fid,'\t\t}\n');
fprintf(fid,'\t}\n');

% Right leg chain
fprintf(fid,'\tJOINT RightUpLeg\n\t{\n');
fprintf(fid,'\t\tOFFSET %.6f %.6f %.6f\n', offsets.RightUpLeg);
fprintf(fid,'\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');
fprintf(fid,'\t\tJOINT RightLeg\n\t\t{\n');
fprintf(fid,'\t\t\tOFFSET %.6f %.6f %.6f\n', offsets.RightLeg);
fprintf(fid,'\t\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');
fprintf(fid,'\t\t\tJOINT RightFoot\n\t\t\t{\n');
fprintf(fid,'\t\t\t\tOFFSET %.6f %.6f %.6f\n', offsets.RightFoot);
fprintf(fid,'\t\t\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');
fprintf(fid,'\t\t\t\tJOINT RightToe\n\t\t\t\t{\n');
fprintf(fid,'\t\t\t\t\tOFFSET %.6f %.6f %.6f\n', offsets.RightToe);
fprintf(fid,'\t\t\t\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');
fprintf(fid,'\t\t\t\t\tEnd Site\n\t\t\t\t\t{\n\t\t\t\t\t\tOFFSET 0.000000 0.000000 0.000000\n\t\t\t\t\t}\n');
fprintf(fid,'\t\t\t\t}\n');
fprintf(fid,'\t\t\t}\n');
fprintf(fid,'\t\t}\n');
fprintf(fid,'\t}\n');

% Spine + head + arms (nested as in example)
fprintf(fid,'\tJOINT Spine\n\t{\n');
fprintf(fid,'\t\tOFFSET %.6f %.6f %.6f\n', offsets.Spine);
fprintf(fid,'\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');

fprintf(fid,'\t\tJOINT Spine1\n\t\t{\n');
fprintf(fid,'\t\t\tOFFSET %.6f %.6f %.6f\n', offsets.Spine1);
fprintf(fid,'\t\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');

fprintf(fid,'\t\t\tJOINT Spine2\n\t\t\t{\n');
fprintf(fid,'\t\t\t\tOFFSET %.6f %.6f %.6f\n', offsets.Spine2);
fprintf(fid,'\t\t\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');

fprintf(fid,'\t\t\t\tJOINT Neck\n\t\t\t\t{\n');
fprintf(fid,'\t\t\t\t\tOFFSET %.6f %.6f %.6f\n', offsets.Neck);
fprintf(fid,'\t\t\t\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');

fprintf(fid,'\t\t\t\t\tJOINT Head\n\t\t\t\t\t{\n');
fprintf(fid,'\t\t\t\t\t\tOFFSET %.6f %.6f %.6f\n', offsets.Head);
fprintf(fid,'\t\t\t\t\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');
fprintf(fid,'\t\t\t\t\t\tEnd Site\n\t\t\t\t\t\t{\n\t\t\t\t\t\t\tOFFSET 0.000000 0.000000 0.000000\n\t\t\t\t\t\t}\n');
fprintf(fid,'\t\t\t\t\t}\n');
fprintf(fid,'\t\t\t\t}\n');

% Left shoulder/arm
fprintf(fid,'\t\t\t\tJOINT LeftShoulder\n\t\t\t\t{\n');
fprintf(fid,'\t\t\t\t\tOFFSET %.6f %.6f %.6f\n', offsets.LeftShoulder);
fprintf(fid,'\t\t\t\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');
fprintf(fid,'\t\t\t\t\tJOINT LeftArm\n\t\t\t\t\t{\n');
fprintf(fid,'\t\t\t\t\t\tOFFSET %.6f %.6f %.6f\n', offsets.LeftArm);
fprintf(fid,'\t\t\t\t\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');
fprintf(fid,'\t\t\t\t\t\tJOINT LeftForeArm\n\t\t\t\t\t\t{\n');
fprintf(fid,'\t\t\t\t\t\t\tOFFSET %.6f %.6f %.6f\n', offsets.LeftForeArm);
fprintf(fid,'\t\t\t\t\t\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');
fprintf(fid,'\t\t\t\t\t\t\tJOINT LeftHand\n\t\t\t\t\t\t\t{\n');
fprintf(fid,'\t\t\t\t\t\t\t\tOFFSET %.6f %.6f %.6f\n', offsets.LeftHand);
fprintf(fid,'\t\t\t\t\t\t\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');
fprintf(fid,'\t\t\t\t\t\t\t\tEnd Site\n\t\t\t\t\t\t\t\t{\n\t\t\t\t\t\t\t\t\tOFFSET 0.000000 0.000000 0.000000\n\t\t\t\t\t\t\t\t}\n');
fprintf(fid,'\t\t\t\t\t\t\t}\n\t\t\t\t\t\t}\n\t\t\t\t\t}\n\t\t\t\t}\n');

% Right shoulder/arm
fprintf(fid,'\t\t\t\tJOINT RightShoulder\n\t\t\t\t{\n');
fprintf(fid,'\t\t\t\t\tOFFSET %.6f %.6f %.6f\n', offsets.RightShoulder);
fprintf(fid,'\t\t\t\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');
fprintf(fid,'\t\t\t\t\tJOINT RightArm\n\t\t\t\t\t{\n');
fprintf(fid,'\t\t\t\t\t\tOFFSET %.6f %.6f %.6f\n', offsets.RightArm);
fprintf(fid,'\t\t\t\t\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');
fprintf(fid,'\t\t\t\t\t\tJOINT RightForeArm\n\t\t\t\t\t\t{\n');
fprintf(fid,'\t\t\t\t\t\t\tOFFSET %.6f %.6f %.6f\n', offsets.RightForeArm);
fprintf(fid,'\t\t\t\t\t\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');
fprintf(fid,'\t\t\t\t\t\t\tJOINT RightHand\n\t\t\t\t\t\t\t{\n');
fprintf(fid,'\t\t\t\t\t\t\t\tOFFSET %.6f %.6f %.6f\n', offsets.RightHand);
fprintf(fid,'\t\t\t\t\t\t\t\tCHANNELS 3 Zrotation Yrotation Xrotation\n');
fprintf(fid,'\t\t\t\t\t\t\t\tEnd Site\n\t\t\t\t\t\t\t\t{\n\t\t\t\t\t\t\t\t\tOFFSET 0.000000 0.000000 0.000000\n\t\t\t\t\t\t\t\t}\n');
fprintf(fid,'\t\t\t\t\t\t\t}\n\t\t\t\t\t\t}\n\t\t\t\t\t}\n\t\t\t\t}\n');

% Close spine block
fprintf(fid,'\t\t\t}\n\t\t}\n\t}\n');

% End root
fprintf(fid,'}\n');

%% --- Motion header ---
numFrames = height(T);
fprintf(fid,'MOTION\n');
fprintf(fid,'Frames: %d\n', numFrames);
fprintf(fid,'Frame Time: %.6f\n', frameTime);

%% --- Build channel name list in the written order ---
channelNames = {};
% root pos + rot (pos then Z Y X rotations)
channelNames = [channelNames, {'Hips_Xposition','Hips_Yposition','Hips_Zposition',...
                               'Hips_Zrotation','Hips_Yrotation','Hips_Xrotation'}];

% For each joint after root, channel order is Z Y X
for j = 2:numel(jointOrder)
    nm = jointOrder{j};
    channelNames = [channelNames, {[nm '_Zrotation'], [nm '_Yrotation'], [nm '_Xrotation']}];
end

%% --- Helper: get value or 0 if missing ---
hasCol = @(name) ismember(name, T.Properties.VariableNames);
getVal = @(tbl, name, idx) ( hasCol(name) * tbl{idx, name} + (~hasCol(name)) * 0 );
%% --- Frame construction and write (matches channelNames order) ---
for fi = 1:numFrames
    frame = zeros(1, numel(channelNames));
    % Hips positions
    % frame(1) = getVal(T,'pelvis_tx',fi);
    % frame(2) = getVal(T,'pelvis_tz',fi);
    % frame(3) = getVal(T,'pelvis_ty',fi);

    % frame(1) = getVal(T,'pelvis_tx',fi)*100;
    % frame(2) = getVal(T,'pelvis_ty',fi)*100;
    % frame(3) = getVal(T,'pelvis_tz',fi)*100;
    
    frame(1) = 0;
    frame(2) = sin(fi/10)*100; %getVal(T,'pelvis_ty',fi)*100;
    frame(3) = 0;

    % Hips rotations: Z Y X order (use pelvis_rotation -> Z, pelvis_list -> Y, pelvis_tilt -> X)
    % frame(4) = getVal(T,'pelvis_rotation',fi);  % Zrotation
    % frame(5) = getVal(T,'pelvis_list',fi);      % Yrotation
    % frame(6) = getVal(T,'pelvis_tilt',fi) + 90;      % Xrotation

    frame(4) = 90;  % Zrotation
    frame(5) = 0;      % Yrotation
    frame(6) = 90;      % Xrotation

    % Now fill other joints in same pre-order as jointOrder (indices start at 7)
    % compute base index for joint j: base = 6 + 3*(j-2) + 1  (1-based)
    for j = 2:numel(jointOrder)
        nm = jointOrder{j};
        base = 6 + 3*(j-2) + 1;
        % default zeros
        z = 0; y = 0; x = 0;

        switch nm
            case 'LeftUpLeg'
                % hip_rotation_l -> Z, hip_adduction_l -> Y, hip_flexion_l -> X
                x = getVal(T,'hip_rotation_l',fi) + 180;
                y = getVal(T,'hip_adduction_l',fi);
                z = getVal(T,'hip_flexion_l',fi) + 180;
                
                % x = getVal(T,'hip_adduction_l',fi) + 180;
                % y = getVal(T,'hip_rotation_l',fi);
                % z = getVal(T,'hip_flexion_l',fi) + 180;

                % z = 180;
                % y = 0;
                % x = 180;
            case 'LeftLeg'
                % knee -> Xrotation
                z = getVal(T,'knee_angle_l',fi);
                y = 0;
                x = 0;
            case 'LeftFoot'
                % ankle -> X, subtalar -> Y
                x = 0;
                y = getVal(T,'subtalar_angle_l',fi);
                z = getVal(T,'ankle_angle_l',fi);
            case 'LeftToe'
                % mtp -> Z
                x = 0;
                y = 0;
                z = getVal(T,'mtp_angle_l',fi);
            case 'RightUpLeg'
                x = getVal(T,'hip_rotation_r',fi) - 180;
                y = getVal(T,'hip_adduction_r',fi);
                z = getVal(T,'hip_flexion_r',fi) + 180;
                
                % x = getVal(T,'hip_adduction_r',fi) + 180;
                % y = getVal(T,'hip_rotation_r',fi);
                % z = getVal(T,'hip_flexion_r',fi) + 180;

                % z = -180;
                % y = 0;
                % x = -180;
            case 'RightLeg'
                z = getVal(T,'knee_angle_r',fi);
                y = 0; 
                x = 0;
            case 'RightFoot'
                x = 0; 
                y = getVal(T,'subtalar_angle_r',fi); 
                z = getVal(T,'ankle_angle_r',fi);
            case 'RightToe'
                x = 0; 
                y = 0; 
                z = getVal(T,'mtp_angle_r',fi);
            % case 'Spine'
            %     % lumbar_rotation -> Z, lumbar_bending -> Y, lumbar_extension -> X
            %     z = getVal(T,'lumbar_rotation',fi);
            %     y = getVal(T,'lumbar_bending',fi);
            %     x = getVal(T,'lumbar_extension',fi);
            
        end
    
        frame(base + 0) = z;
        frame(base + 1) = y;
        frame(base + 2) = x;
    end
    
    % for col = 31:69
    %     rowIdx = mod(fi-1, 45) + 1;
    %     varName = sprintf('Var%d', col);
    %     if ismember(varName, walk1_subject1.Properties.VariableNames)
    %         frame(col) = walk1_subject1{rowIdx, varName};
    %     end
    % end

    for col = 31:69
        rowIdx = 1;
        varName = sprintf('Var%d', col);
        if ismember(varName, walk1_subject1.Properties.VariableNames)
            frame(col) = walk1_subject1{rowIdx, varName};
        end
    end

    % write frame line as space-separated floats
    fprintf(fid, repmat('%f ', 1, numel(frame)), frame);
    fprintf(fid, '\n');
end

fclose(fid);
disp(['BVH saved to: ' outputBVH]);