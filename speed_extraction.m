steadyspeed = data(data.Header > 50 & data.Header < 82, :);

% save('test.mat', 'steadyspeed');
S = load('test.mat')
T = S.steadyspeed;
writetable(T, 'steadyspeed.csv');