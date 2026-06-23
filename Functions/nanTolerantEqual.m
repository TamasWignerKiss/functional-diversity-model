function tf = nanTolerantEqual(A, B, varargin)
% This function compares two matrices for element-wise equality. NaNs are taken to be equal. Equality is assumed up to a given error.
%
% Author: (anonymized for double-anonymous peer review)

    %% Parse input arguments
    p = inputParser;
    addRequired(p, 'A');
    addRequired(p, 'B');
    addParameter(p, 'Debug', false)
    addParameter(p, 'epsilon', 1e-5, @isnumeric)
    
    parse(p, A, B, varargin{:});

    %% Comparison
    % Check matrix dimensions
    if ~isequal(size(A), size(B))
        tf = false;
        return;
    end
    
    % Verify NaN patterns match
    nanMaskA = isnan(A);
    nanMaskB = isnan(B);
    if ~isequal(nanMaskA, nanMaskB)
        tf = false;
        return;
    end
    
    % Compare non-NaN elements within tolerance
    nonNanMask = ~nanMaskA;
    A_nonNaN = A(nonNanMask);
    B_nonNaN = B(nonNanMask);
    diff = abs(A_nonNaN - B_nonNaN);
    tf = all(diff < p.Results.epsilon);

    %% Print debug info if asked for
    if p.Results.Debug
        fprintf('The difference matrix is:\n')
        disp(A-B)
        fprintf('\nThe largest difference is: %0.4e\n', max(abs(A-B), [], 'all'))
    end
end
