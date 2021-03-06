% *************************************************************************
% * Copyright 2016 University of Bonn
% *
% * authors:
% *  - Sebastian Merzbach <merzbach@cs.uni-bonn.de>
% *
% * last modification date: 2016-01-04
% *
% * This file is part of btflib.
% *
% * btflib is free software: you can redistribute it and/or modify it under
% * the terms of the GNU Lesser General Public License as published by the
% * Free Software Foundation, either version 3 of the License, or (at your
% * option) any later version.
% *
% * btflib is distributed in the hope that it will be useful, but WITHOUT
% * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
% * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
% * License for more details.
% *
% * You should have received a copy of the GNU Lesser General Public
% * License along with btflib.  If not, see <http://www.gnu.org/licenses/>.
% *
% *************************************************************************
%
% This function computes the halfway and difference vectors of the Rusinkiewicz
% parameterization. Input are either two (2 x N) or (3 x N) arrays containing
% pairs of incoming and outgoing unit length directions in spherical or
% cartesian coordinates. The function optionally returns the halfway and
% difference vectors in spherical coordinates as third and fourth arguments.
function [half, diff, half_sph, diff_sph] = cart2rus(light_dirs, view_dirs)
    % input parsing
    if size(light_dirs, 1) == 2 && size(view_dirs, 1) == 2
        % bring everything to cartesian coordinates
        light_dirs = utils.sph2cart2(light_dirs(1, :), light_dirs(2, :));
        view_dirs = utils.sph2cart2(view_dirs(1, :), view_dirs(2, :));
    elseif size(light_dirs, 1) ~= 3 && size(view_dirs, 1) ~= 3
        error('input arrays must both be (2 x N) or (3 x N)');
    end
    n = size(light_dirs);
    n(1) = [];
    light_dirs = reshape(light_dirs, [3, prod(n)]);
    view_dirs = reshape(view_dirs, [3, prod(n)]);
    
    % compute halfway vector & bring to spherical coordinates
    half = light_dirs + view_dirs;
    half = half ./ repmat(sqrt(sum(half .^ 2, 1)), 3, 1);
    half_sph = utils.cart2sph2(half(1, :), half(2, :), half(3, :));

    cos_theta = cos(-half_sph(1, :));
    sin_theta = sin(-half_sph(1, :));
    cos_phi = cos(-half_sph(2, :));
    sin_phi = sin(-half_sph(2, :));
    
    % compute difference vector
    % (the slow but readable way)
%     diff = light_dirs;
%     for jj = 1 : n
%        rot_z = [cos_theta(jj), -sin_theta(jj), 0;
%            sin_theta(jj), cos_theta(jj), 0;
%            0, 0, 1];
%        rot_y = [cos_phi(jj), 0, sin_phi(jj);
%            0, 1, 0;
%            -sin_phi(jj), 0, cos_phi(jj)];
%        diff(:, jj) = rot_y * rot_z * light_dirs(:, jj);
%     end
    
    % this is the same computation of R_y * R_z * light as above but in a much
    % more efficient expression
    diff = zeros(3, prod(n));
    diff(1, :) =	cos_theta .* cos_phi .* light_dirs(1, :) ...
                  - cos_theta .* sin_phi .* light_dirs(2, :) ...
                  + sin_theta .* light_dirs(3, :);
    diff(2, :) =	sin_phi .* light_dirs(1, :) ...
                  + cos_phi .* light_dirs(2, :);
    diff(3, :) =  - sin_theta .* cos_phi .* light_dirs(1, :) ...
                  + sin_theta .* sin_phi .* light_dirs(2, :) ...
                  + cos_theta .* light_dirs(3, :);
    
    diff = diff ./ repmat(sqrt(sum(diff .^ 2, 1)), 3, 1);
    
    if nargout > 3
        diff_sph = utils.cart2sph2(diff(1, :), diff(2, :), diff(3, :));
        diff_sph = reshape(diff_sph, [2, n]);
        half_sph = reshape(half_sph, [2, n]);
    end
    
    half = reshape(half, [3, n]);
    diff = reshape(diff, [3, n]);
end
