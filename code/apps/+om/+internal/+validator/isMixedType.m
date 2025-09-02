function tf = isMixedType(object)
    tf = isa(object, 'openminds.internal.abstract.MixedTypeSet');
end