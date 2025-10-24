function logoFilePath = getLogoPath(name, mode)
%getLogoPath - Get filepath for a logo resource
    arguments
        name (1,1) string {mustBeMember(name, "openMINDS")} = "openMINDS"
        mode (1,1) string {mustBeMember(mode, ["light", "dark"])} = "light"
    end
    % Todo: use ndi.util.toolboxdir
    rootPath = om.internal.rootpath;
    logoFolderPath = fullfile(rootPath, 'apps', 'resources', 'images');
    fileName = sprintf('%s_logo_%s.png', name, mode);
    logoFilePath = fullfile(logoFolderPath, fileName);
end
