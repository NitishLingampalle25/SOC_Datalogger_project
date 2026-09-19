// Shared timescale stub.
// Listed as the FIRST file in every VCS filelist so that all subsequent
// modules that lack an explicit `timescale directive inherit this setting.
// VCS rule: a `timescale is "sticky" – it applies to all modules compiled
// after it until another `timescale (or `resetall) overrides it.
`timescale 1ns / 1ps
