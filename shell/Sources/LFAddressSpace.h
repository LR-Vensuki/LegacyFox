// Malloc zones of system libraries (the GPU driver's above all) allocate from
// Gecko's allocator, so they hold no mostly empty 8 MB regions.
#ifdef __cplusplus
extern "C" {
#endif
void LFAddressSpaceInstall(void);
#ifdef __cplusplus
}
#endif
