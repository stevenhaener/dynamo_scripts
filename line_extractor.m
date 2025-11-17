
walk1_subject1 = extractBVHLines('/home/stevenh/Documents/ubisoft-laforge-animation-dataset/lafan1/lafan1/walk1_subject1.bvh', 290:334);

function extractedTable = extractBVHLines(filePath, lineNumbers)

    if ~isfile(filePath)
        error('The specified file does not exist.');
    end

    fid = fopen(filePath, 'r');
    if fid == -1
        error('Error opening the file.');
    end

    extracted = {};
    lineIndex = 1;

    while ~feof(fid)
        currentLine = fgetl(fid);
        if ismember(lineIndex, lineNumbers)

            % split into tokens
            tokens = strsplit(strtrim(currentLine));

            % convert each token to a number
            numTokens = str2double(tokens);

            extracted{end+1} = numTokens;   % store numeric row
        end
        lineIndex = lineIndex + 1;
    end

    fclose(fid);

    % Pad rows so all same width
    maxLen = max(cellfun(@numel, extracted));
    for i = 1:numel(extracted)
        if numel(extracted{i}) < maxLen
            extracted{i}(end+1:maxLen) = NaN;
        end
    end

    % Create variable names Var1, Var2, ...
    varNames = "Var" + (1:maxLen);

    extractedTable = array2table(vertcat(extracted{:}), 'VariableNames', varNames);
end
