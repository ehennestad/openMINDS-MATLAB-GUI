function tf = isMixedTypeClassName(className)

    arguments
        className %(1,1) string
    end

    try
        mc = meta.class.fromName(className);
        superClassNames = {mc.SuperclassList.Name};
        expectedSuperClassName = "openminds.internal.abstract.MixedTypeSet";
        tf = any( strcmp(superClassNames, expectedSuperClassName) );
    catch
        tf = false;
    end
end
