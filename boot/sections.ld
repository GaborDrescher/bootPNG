/* vim: set et ts=4 sw=4: */

SECTIONS
 {
   . = 0x1000000;     /* Startadresse des Systems */

   .text :
    {
      *(".text")
      *(".text$")
      *(".init")
      *(".fini")
      *(".gnu.linkonce.*")
    }

    /* Liste von Startadressen der globalen Konstruktoren (benoetigt ab gcc 4.7) */
    .init_array     :
    {
       PROVIDE_HIDDEN (__init_array_start = .);
       KEEP (*(SORT(.init_array.*)))
       KEEP (*(.init_array))
       PROVIDE_HIDDEN (__init_array_end = .);
    }

   /* Startcode fuer die APs, wird von SMPSystem::copyStartAPtoLowMem() reloziert */
    .vesa_detection ALIGN(0x10):
    {
	__VESA_DETECTION_CODE_START__ = .;
	*(".vesa_detection")
	*(".vesa_detection$")
	__VESA_DETECTION_CODE_END__ = .;
    }

   .data :
    {
      *(".data")
      *(".data$")
      *(".rodata")
      ___CTOR_LIST__ = .;
      *(".ctors")
      *(".ctor")
      ___CTOR_LIST_END__ = .;
      ___DTOR_LIST__ = .;
      *(".dtors")
      *(".dtor")
      ___DTOR_LIST_END__ = .;
      *(".got")
      *(".got.plt")
      *(".eh_frame")
      *(".eh_fram")
      *(".jcr")
    }

   .bss : 
    {
      ___BSS_START___ = .;
      *(".bss")
      *(".bss.*")
    }
    ___IMG_END___ = .;
	/DISCARD/ :
	{
		*(.comment)
		*(.comment.*)
		*(.note)
		*(.note.*)
	}
 }
