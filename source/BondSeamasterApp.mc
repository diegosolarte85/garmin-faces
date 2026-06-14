import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Application entry point for the 007 First Light watch face.
class BondSeamasterApp extends Application.AppBase {
    private var _view as BondSeamasterView?;

    public function initialize() {
        AppBase.initialize();
    }

    public function onStart(state as Dictionary?) as Void {}

    public function onStop(state as Dictionary?) as Void {}

    public function getInitialView() as Array<Views or InputDelegates>? {
        _view = new BondSeamasterView();
        return [_view] as Array<Views or InputDelegates>;
    }

    // Re-read settings and invalidate cached static art on change. (R5.2)
    public function onSettingsChanged() as Void {
        if (_view != null) {
            _view.reloadSettings();
        }
        WatchUi.requestUpdate();
    }
}
