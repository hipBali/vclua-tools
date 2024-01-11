-- ***************************************
-- VCLua Form tool
-- Copyright (C) 2013-2023 Hi-Project Ltd.
--
-- builder form components
-- ***************************************
VCL = require "vcl.core"

frmMain = VCL.Form()
frmMain._ = {
	-- Position='poDesktopCenter',
	Left=0,
	Top=30,
	Width=600,
	Caption='VCLua form tool v'.._VCLFB_VERSION,
	Height=600,
}
	compImages = VCL.ImageList(frmMain)
	toolImages = VCL.ImageList(frmMain)
	compImages._ = {
		Height=32,
		Width=32,	
	}
	toolImages._ = {
		Height=16,
		Width=16,	
	}
	pnTree = VCL.Panel(frmMain)
	pnTree._ = {
		Width=200,
		Align='alLeft',
		TabOrder=0,
		Caption='pnTree',
		Height=469,
		BevelInner="bvNone",
		BevelOuter="bvNone",
	}
		tvForm = VCL.TreeView(pnTree)
		tvForm._ = {
			Top=1,	
			AutoExpand=true,
			Width=238,
			ScrollBars='ssAutoBoth',
			Align='alClient',
			DefaultItemHeight=32,
			DragMode='dmAutomatic',	
			Options='[tvoAutoExpand,tvoAutoItemHeight,tvoKeepCollapsedNodes,tvoRightClickSelect,tvoRowSelect,tvoShowButtons,tvoShowLines,tvoShowRoot,tvoToolTips,tvoThemedDraw]', 
			Left=1,
			TabOrder=0,
			Height=467,
			StateImages=compImages,
			ExpandSignType='tvestPlusMinus',
			BorderStyle="bsSingle",
			ShowHint=true,
			Hint="Ctrl + Click to move component"
		}
	splitter = VCL.Splitter(frmMain)	
	splitter._ = {
		Width=5,
		Height=469,
		Top=0,
		Left=240,
	}
	pgTabs = VCL.PageControl(frmMain)
	pgTabs._ = {
		TabOrder=0,
		Align='alClient',
		TabIndex=1,
		Height=467,
		Width=558,
		ActivePage=tsComponent,
	}
		tsCompTree = VCL.TabSheet(pgTabs)
		tsCompTree._ = {
			Caption='Components',
		}
			pnCompSelect = VCL.Panel(tsCompTree)
			pnCompSelect._={
				Align='alTop',
				Caption='',
				Height=28,
				BevelInner="bvLowered",
				BevelOuter="bvNone",
				visible = false
			}
			chkComp = VCL.RadioButton(pnCompSelect)
			chkCompD = VCL.RadioButton(pnCompSelect)
			chkCompI = VCL.RadioButton(pnCompSelect)
				chkComp._={
					Left = 4,
					Top = 4,
					Caption ='Visible components',
					Checked = true,
					Name = "chkComp",
					visible = false
				}
				chkCompD._={
					Left = 200,
					Top = 4,
					Caption ='Dialogs',
					Name = "chkCompD",
					visible = false
				}
				chkCompI._={
					Left = 350,
					Top = 4,
					Caption ='Invisible components',
					Name = "chkCompI",
					visible = false
				}

			compListTree = VCL.TreeView(tsCompTree)
			compListTree._ = {
				Top=1,	
				AutoExpand=true,
				Width=238,
				ScrollBars='ssAutoVertical',
				Align='alClient',
				DefaultItemHeight=32,
				DragMode='dmAutomatic',	
				Options='[tvoAutoExpand,tvoAutoItemHeight,tvoKeepCollapsedNodes,tvoRightClickSelect,tvoRowSelect,tvoShowButtons,tvoShowLines,tvoToolTips,tvoThemedDraw]', 
				Left=1,
				TabOrder=0,
				Height=467,
				StateImages=compImages,
				ExpandSignType='tvestPlusMinus',
				BorderStyle="bsSingle",
				ReadOnly = true,
			}
		
		tsProperties = VCL.TabSheet(pgTabs)
		tsProperties._ = {
			Caption='Properties',
		}
			compPropGrid = VCL.PropertyGrid(tsProperties)
			compPropGrid._ = {
				Align='alClient',
				-- Filter='[tkInteger,tkChar,tkEnumeration,tkFloat,tkSet,tkMethod,tkSString,tkLString,tkAString,tkWString,tkVariant,tkArray,tkRecord,tkInterface,tkClass,tkObject,tkWChar,tkBool,tkInt64,tkQWord,tkDynArray,tkInterfaceRaw,tkProcVar,tkUString,tkUChar,tkHelper,tkFile,tkClassRef,tkPointer]'
				Filter='[tkInteger, tkChar, tkEnumeration, tkFloat, tkSet, tkSString, tkLString, tkAString, tkWString, tkVariant, tkClass, tkWChar, tkBool, tkInt64, tkProcVar, tkUString, tkUChar, tkFile]',
			}
