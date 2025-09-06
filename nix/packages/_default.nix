{ symlinkJoin, blender-daily-wrapped }:
symlinkJoin {
  name = "blender-daily";
  paths = [
    blender-daily-wrapped
  ];
}
