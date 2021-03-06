% *************************************************************************
% * Copyright 2015 University of Bonn
% *
% * authors:
% *  - Sebastian Merzbach <merzbach@cs.uni-bonn.de>
% *
% * last modification date: 2016-04-05
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
% Decode a single texture from a bidirectional image file (BDI).
% 
% Warning: if not buffered, this is extremely slow, as BDIs store chunks of
% ABRDFs, i.e. the whole file needs to be read to obtain a single texture!
%
% TODO: at the moment we're completely reading all chunks, instead one should
% make use of fread's skipping parameter to only read what we really need.
function img = decode_bdi_texture(obj, l, v)
    n = numel(l);
    assert(numel(v) == n);
    n_c = obj.meta.num_channels;
    n_abrdfs = obj.meta.abrdfs_per_chunk;
    data_type = 'uint16';
    if isfield(obj.data, 'chunks') && ~isempty(obj.data.chunks)
        data_type = class(obj.data.chunks);
    end
    img = zeros(n_c, n, obj.meta.width, obj.meta.height, data_type);

    for ii = 1 : n
        clvxy_inds = sub2ind([obj.meta.num_channels, obj.meta.nL, obj.meta.nV, n_abrdfs], ...
            repmat(1 : n_c, n_abrdfs, 1)', repmat(l(ii), n_abrdfs, n_c)', ...
            repmat(v(ii), n_abrdfs, n_c)', repmat(1 : n_abrdfs, n_c, 1));

        if all(obj.data.chunks_buffered)
            % full BDI in buffer
            tmp = reshape(obj.data.chunks(clvxy_inds, :), n_c, obj.meta.width, []);
            tmp = tmp(:, obj.meta.abrdf_index_logical_to_storage ~= -1);
            img(:, ii, obj.meta.mask) = tmp;
        else
            % partially or not buffered at all
            abrdf_index_storage_to_logical = find(obj.meta.mask ~= 0);
            [xs, ys] = ind2sub([obj.meta.width, obj.meta.height], abrdf_index_storage_to_logical);
            abrdf_index_storage_to_logical = sub2ind([obj.meta.width, obj.meta.height], xs, ys);

            % always try to make used of already buffered chunks
            if any(obj.data.chunks_buffered)
                % only display buffered data, don't read anything from file
                tmp = reshape(obj.data.chunks(clvxy_inds, :), n_c, obj.meta.width, []);
                img(:, ii, :, 1 : size(tmp, 3)) = tmp;
            end

            if obj.data.textures_from_file && ~obj.data.only_use_buffered
                % optionally fallback to reading from file for unbuffered chunks
                chunks_missing = find(~obj.data.chunks_buffered);
                obj.data.fid = fopen(obj.meta.file_name, 'r');
                for ci = 1 : numel(chunks_missing)
                    chunk_index = chunks_missing(ci);
                    % only assign the texels that are not masked!
                    storage_abrdf_inds = (chunk_index - 1) * obj.meta.abrdfs_per_chunk + 1 : ...
                        min(max(obj.meta.abrdf_index_logical_to_storage), chunk_index * obj.meta.abrdfs_per_chunk);
                    logical_abrdf_inds = abrdf_index_storage_to_logical(storage_abrdf_inds);

                    % every 10 chunks, update the intermediate image
                    if mod(ci, 10) == 0
                        img_disp = permute(img(:, 1, :, :), [4, 3, 1, 2]);
                        if strcmp(data_type, 'uint16')
                            img_disp = halfprecision(img_disp, 'single');
                        end
                        obj.progress(ci / numel(chunks_missing), 'reading texture', ...
                            'texture', img_disp);
                    end
                    obj.data.current_chunk = reshape(obj.get_bdi_chunk(chunk_index), ...
                        obj.meta.num_channels, obj.meta.nL, obj.meta.nV, []);
                    img(:, logical_abrdf_inds) = squeeze(obj.data.current_chunk(:, l(ii), v(ii), :));
                end
                fclose(obj.data.fid);
                obj.progress();
            end
        end
    end
    
    % convert half precision floats to single precision floats
    if strcmp(data_type, 'uint16')
        img = halfprecision(img, 'single');
    end
    img = permute(img, [4, 3, 2, 1]);
end
