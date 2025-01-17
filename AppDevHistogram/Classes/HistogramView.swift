//
//  HistogramView.swift
//  Eatery
//
//  Created by William Ma on 10/10/19.
//  Copyright © 2019 CUAppDev. All rights reserved.
//

import SnapKit
import UIKit

public protocol HistogramViewDataSource: AnyObject {

    func numberOfDataPoints(for histogramView: HistogramView) -> Int
    func histogramView(_ histogramView: HistogramView, relativeValueOfDataPointAt index: Int) -> Double
    func histogramView(_ histogramView: HistogramView, descriptionForDataPointAt index: Int) -> NSAttributedString?
    func numberOfDataPointsPerTickMark(for histogramView: HistogramView) -> Int?
    func histogramView(_ histogramView: HistogramView, titleForTickMarkAt index: Int) -> String?

    func defaultBarColor(for histogramView: HistogramView) -> UIColor
    func highlightedBarColor(for histogramView: HistogramView) -> UIColor
    func font(for histogramView: HistogramView) -> UIFont
}

public protocol HistogramViewDelegate: AnyObject {

    func histogramView(_ histogramView: HistogramView, didChangeIndex index: Int)

}

public class HistogramView: UIView {

    public weak var dataSource: HistogramViewDataSource?
    public weak var delegate: HistogramViewDelegate?

    /// The bottom line that extends along the bottom across the width of the
    /// histogram
    private let axisView = UIView()

    /// The layoutGuide for which all views in `barContainerViews` are contained
    private let barsLayoutGuide = UILayoutGuide()
    private var barContainerViews: [BarContainerView] = []

    private let tickLabelContainerView = UIView()
    private var tickLabelViews: [TickLabelView] = []

    private var selectedBarIndex: Int?
    private let tagView = BarTagView()
    private let tagDropDownView = UIView()

    private let selectionFeedbackGenerator = UISelectionFeedbackGenerator()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setUpAxisView()
        setUpBarsLayoutGuide()
        setUpTickLabelContainerView()
        setUpTagAndDropDownView()
        setUpGestureRecognizers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUpAxisView() {
        axisView.backgroundColor = .inactive
        addSubview(axisView)

        axisView.snp.makeConstraints { make in
            make.height.equalTo(2)
            make.bottom.equalToSuperview().inset(48)
            make.leading.trailing.equalToSuperview()
        }
    }

    private func setUpBarsLayoutGuide() {
        addLayoutGuide(barsLayoutGuide)
        barsLayoutGuide.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(48)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(axisView.snp.top)
        }
    }

    private func setUpTickLabelContainerView() {
        addSubview(tickLabelContainerView)
        tickLabelContainerView.snp.makeConstraints { make in
            make.top.equalTo(axisView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        let finalTickMark = UIView()
        finalTickMark.backgroundColor = .inactive

        addSubview(finalTickMark)
        finalTickMark.snp.makeConstraints { make in
            make.width.equalTo(2)
            make.height.equalTo(6)
            make.trailing.equalTo(axisView.snp.trailing)
            make.top.equalTo(axisView.snp.bottom)
        }
    }

    private func setUpTagAndDropDownView() {
        addSubview(tagView)

        addSubview(tagDropDownView)
        tagDropDownView.backgroundColor = .inactive
    }

    private func setUpGestureRecognizers() {
        let panGestureRecognizer =
            UIPanGestureRecognizer(target: self, action: #selector(holdDownGestureDidChangeState(_:)))
        panGestureRecognizer.delegate = self
        addGestureRecognizer(panGestureRecognizer)

        let tapGestureRecognizer =
            UITapGestureRecognizer(target: self, action: #selector(tapGestureRecognizeDidChangeState(_:)))
        tapGestureRecognizer.numberOfTapsRequired = 1
        addGestureRecognizer(tapGestureRecognizer)
    }

    public func reloadData() {
        tearDownBars()
        setUpBars()

        tearDownTickMarks()
        setUpTickMarks()
    }

    private func setUpBars() {
        guard let dataSource = dataSource else {
            return
        }

        let barCount = dataSource.numberOfDataPoints(for: self)
        guard barCount >= 1 else {
            return
        }

        let bezierPath = UIBezierPath()
        var previous: BarContainerView?
        for i in 0..<barCount {
            let barContainerView = BarContainerView()

            let heightFactor = dataSource.histogramView(self, relativeValueOfDataPointAt: i)
            let defaultBarColor = dataSource.defaultBarColor(for: self)
            let highlightedBarColor = dataSource.highlightedBarColor(for: self)
            barContainerView.configure(heightFactor: heightFactor, defaultColor: defaultBarColor, highlightedColor: highlightedBarColor)
            
            if let superview = superview {
                bezierPath.move(to: CGPoint.init(x: (superview.bounds.width / CGFloat(barCount)) * CGFloat(i), y: superview.bounds.height * CGFloat(heightFactor)))
            }

            addSubview(barContainerView)
            barContainerView.snp.makeConstraints { make in
                make.width.equalTo(barsLayoutGuide).dividedBy(barCount)
                make.top.bottom.equalTo(barsLayoutGuide)

                if let previous = previous {
                    make.leading.equalTo(previous.snp.trailing)
                } else {
                    make.leading.equalToSuperview()
                }
            }

            barContainerViews.append(barContainerView)
            previous = barContainerView
        }
        
        bezierPath.close()
    }

    private func tearDownBars() {
        for view in barContainerViews {
            view.removeFromSuperview()
        }
        barContainerViews.removeAll(keepingCapacity: true)
    }

    private func setUpTickMarks() {
        guard let dataSource = dataSource else {
            return
        }

        let pointsPerTick = dataSource.numberOfDataPointsPerTickMark(for: self) ?? 1

        for (i, barContainerView) in barContainerViews.enumerated() where i % pointsPerTick == 0 {
            let tickLabel = TickLabelView()
            tickLabel.configure(for: dataSource.font(for: self))
            let title = dataSource.histogramView(self, titleForTickMarkAt: i) ?? ""
            tickLabel.configure(title: title)

            tickLabelContainerView.addSubview(tickLabel)
            tickLabel.snp.makeConstraints { make in
                make.leading.equalTo(barContainerView)
                make.top.bottom.equalToSuperview()
            }

            tickLabelViews.append(tickLabel)
        }
    }

    private func tearDownTickMarks() {
        for tickLabelView in tickLabelViews {
            tickLabelView.removeFromSuperview()
        }
        tickLabelViews.removeAll(keepingCapacity: true)
    }

    @objc private func holdDownGestureDidChangeState(_ sender: UIGestureRecognizer) {
        switch sender.state {
        case .began, .changed:
            if let index = indexOfBar(atPoint: sender.location(in: self)) {
                selectBar(at: index, animated: true, generateFeedback: true)
            }

        case .ended, .cancelled, .failed, .possible:
            break
        }
    }

    @objc private func tapGestureRecognizeDidChangeState(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended, let index = indexOfBar(atPoint: sender.location(in: self)) {
            selectBar(at: index, animated: true, generateFeedback: true)
        }
    }

    // Move the tag and highlight the correct bar
    public func selectBar(at index: Int, animated: Bool, generateFeedback: Bool, force: Bool = false) {
        delegate?.histogramView(self, didChangeIndex: index)
        moveTag(toBarViewAt: index, animated: animated, generateFeedback: generateFeedback, force: force)
        highlightBarView(at: index, animated: animated)
    }

    private func indexOfBar(atPoint point: CGPoint) -> Int? {
        return barContainerViews
            .enumerated()
            .first(where: { $0.element.frame.minX <= point.x && point.x <= $0.element.frame.maxX })?.offset
    }

    private func setShowTag(_ showTag: Bool, animated: Bool) {
        let actions: (() -> Void) = {
            self.tagView.alpha = showTag ? 1 : 0
            self.tagDropDownView.alpha = showTag ? 1 : 0
        }

        if animated {
            UIViewPropertyAnimator(duration: 0.1, curve: .linear, animations: actions).startAnimation()
        } else {
            actions()
        }
    }

    private func moveTag(toBarViewAt index: Int, animated: Bool, generateFeedback: Bool, force: Bool) {
        guard force || (0 <= index && index < barContainerViews.count && selectedBarIndex != index) else {
            return
        }

        selectedBarIndex = index

        tagDropDownView.snp.remakeConstraints { make in
            make.top.equalTo(tagView.snp.bottom)
            make.width.equalTo(2)
            make.bottom.equalTo(barContainerViews[index].barViewTop)
            make.centerX.equalTo(barContainerViews[index])
        }
        layoutIfNeeded()

        let actions: (() -> Void) = {
            let description = self.dataSource?.histogramView(self, descriptionForDataPointAt: index) ?? NSAttributedString()
            self.tagView.configure(description: description)

            self.tagView.snp.remakeConstraints { make in
                make.top.equalToSuperview().inset(2)
                make.centerX.equalTo(self.barContainerViews[index]).priorityMedium()
                make.leading.greaterThanOrEqualTo(self.barsLayoutGuide)
                make.trailing.lessThanOrEqualTo(self.barsLayoutGuide)
            }

            self.layoutIfNeeded()
        }

        if animated {
            UIViewPropertyAnimator(duration: 0.1, curve: .linear, animations: actions).startAnimation()
        } else {
            actions()
        }

        if generateFeedback {
            selectionFeedbackGenerator.selectionChanged()
            selectionFeedbackGenerator.prepare()
        }
    }

    private func highlightBarView(at index: Int, animated: Bool) {
        guard 0 <= index, index < barContainerViews.count else {
            return
        }

        unhighlightBarViews(animated: animated)

        barContainerViews[index].setHighlighted(true, animated: animated)
    }

    private func unhighlightBarViews(animated: Bool) {
        for barContainerView in barContainerViews {
            barContainerView.setHighlighted(false, animated: animated)
        }
    }

}

extension HistogramView: UIGestureRecognizerDelegate {

    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }

        let velocity = panGesture.velocity(in: self)
        return abs(velocity.x) > abs(velocity.y)
    }

}

private class BarContainerView: UIView {

    private let barView = UIView()

    private var defaultColor: UIColor!
    private var highlightedColor: UIColor!

    var barViewTop: ConstraintItem {
        return barView.snp.top
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        barView.isUserInteractionEnabled = false
        barView.layer.cornerRadius = 3
        barView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        addSubview(barView)
        setUpConstraints(heightFactor: 0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(heightFactor: Double, defaultColor: UIColor, highlightedColor: UIColor) {
        // clamp heightFactor to the range [0, 1]
        let clampedHeightFactor = max(0, min(1, heightFactor))
        setUpConstraints(heightFactor: clampedHeightFactor)

        self.defaultColor = defaultColor
        self.highlightedColor = highlightedColor
        barView.backgroundColor = defaultColor
    }

    private func setUpConstraints(heightFactor: Double) {
        barView.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(2)
            make.bottom.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(heightFactor)
        }
    }

    func setHighlighted(_ isHighlighted: Bool, animated: Bool) {
        let actions: (() -> Void) = {
            self.barView.backgroundColor = isHighlighted ? self.highlightedColor : self.defaultColor
        }

        if animated {
            UIViewPropertyAnimator(duration: 0.05, curve: .linear, animations: actions).startAnimation()
        } else {
            actions()
        }
    }

}

private class TickLabelView: UIView {

    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        let tickMark = UIView()
        tickMark.backgroundColor = .inactive

        addSubview(tickMark)
        tickMark.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.width.equalTo(1)
            make.height.equalTo(6)
        }

        titleLabel.textColor = .secondary

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(tickMark.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    func configure(for font: UIFont) {
        titleLabel.font = font
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String) {
        titleLabel.text = title
    }

}

private class BarTagView: UIView {

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        clipsToBounds = true
        layer.cornerRadius = 5
        layer.borderColor = UIColor.inactive.cgColor
        layer.borderWidth = 2

        label.textAlignment = .center
        addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.greaterThanOrEqualTo(90)

            make.leading.trailing.equalToSuperview().inset(16).priority(.high)
            make.top.bottom.equalToSuperview().inset(8).priority(.high)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(description: NSAttributedString) {
        label.attributedText = description
    }

}
