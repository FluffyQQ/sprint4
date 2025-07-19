import UIKit

final class MovieQuizViewController: UIViewController, QuestionFactoryDelegate {

    // MARK: - Outlets
    @IBOutlet private var imageView: UIImageView!
    @IBOutlet private var textLabel: UILabel!
    @IBOutlet private var counterLabel: UILabel!
    @IBOutlet private var noButton: UIButton!
    @IBOutlet private var yesButton: UIButton!
    @IBOutlet private var activityIndicator: UIActivityIndicatorView!

    // MARK: - Properties
    private var currentQuestionIndex = 0
    private var correctAnswers = 0
    private let questionsAmount: Int = 10
    private var questionFactory: QuestionFactoryProtocol?
    private var currentQuestion: QuizQuestion? = nil
    private var statisticService: StatisticServiceProtocol?
    private let resultAlertPresenter = ResultAlertPresenter()
    private let moviesLoader: MoviesLoading = MoviesLoader()

    // MARK: - Lifecycle
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.statisticService = StatisticServiceImplementation()
        showLoadingIndicator()
        let factory = QuestionFactory(moviesLoader: moviesLoader, delegate: self)
        self.questionFactory = factory
        self.questionFactory?.loadData()
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.imageBorderDefaultStyle()
    }

    // MARK: - Actions
    @IBAction private func noButtonClicked(_ sender: UIButton)
    {
        guard let quiz = self.currentQuestion else { return }
        self.showAnswerResult(isCorrect: !quiz.correctAnswer)
    }

    @IBAction private func yesButtonClicked(_ sender: UIButton)
    {
        guard let quiz = self.currentQuestion else { return }
        self.showAnswerResult(isCorrect: quiz.correctAnswer)
    }

    // MARK: - QuestionFactoryDelegate
    func didReceiveNextQuestion(question: QuizQuestion?)
    {
        guard let quiz = question else { return }
        self.currentQuestion = quiz
        let quizStep = self.convert(model: quiz)
        self.show(quiz: quizStep)
    }
    func didLoadDataFromServer() {
        hideLoadingIndicator()
        self.questionFactory?.requestNextQuestion()
    }
    func didFailToLoadData(with error: Error) {
        hideLoadingIndicator()
        showNetworkError(message: error.localizedDescription)
    }

    // MARK: - Quiz Step
    private func convert(model: QuizQuestion) -> QuizStepViewModel
    {
        let quizStep = QuizStepViewModel(
            image: UIImage(data: model.image) ?? UIImage(),
            question: model.text,
            questionNumber: "\(self.currentQuestionIndex + 1)/\(self.questionsAmount)"
        )
        return quizStep
    }

    private func show(quiz quizStep: QuizStepViewModel)
    {
        self.imageView.image = quizStep.image
        self.textLabel.text = quizStep.question
        self.counterLabel.text = quizStep.questionNumber
        self.setAnswerButtonsState(isEnabled: true)
    }

    // MARK: - Quiz Result
    private func showNextQuestionOrResults()
    {
        if self.currentQuestionIndex == self.questionsAmount - 1
        {
            self.statisticService?.store(correct: self.correctAnswers, total: self.questionsAmount)
            guard let bestGame = self.statisticService?.bestGame else { return }
            let statsText = """
                Ваш результат: \(self.correctAnswers)/\(self.questionsAmount)
                Количество сыгранных квизов: \(self.statisticService?.gamesCount ?? 0)
                Рекорд: \(bestGame.correct)/\(bestGame.total) (\(bestGame.date.dateTimeString))
                Средняя точность: \(String(format: "%.2f", self.statisticService?.totalAccuracy ?? 0))%
                """
            let quizResult = AlertModel(
                title: "Этот раунд окончен!",
                message: statsText,
                buttonText: "Сыграть еще раз",
                completion: {
                    [weak self] in
                    guard let self = self else { return }
                    self.currentQuestionIndex = 0
                    self.correctAnswers = 0
                    self.questionFactory?.requestNextQuestion()
                }
            )
            self.resultAlertPresenter.showAlert(on: self, model: quizResult)
        }
        else
        {
            self.imageBorderDefaultStyle()
            self.currentQuestionIndex += 1
            self.questionFactory?.requestNextQuestion()
        }
    }

    // MARK: - Answer Result
    private func showAnswerResult(isCorrect: Bool)
    {
        self.setAnswerButtonsState(isEnabled: false)
        if isCorrect
        {
            self.correctAnswers += 1
        }
        self.imageView.layer.masksToBounds = true
        self.imageView.layer.borderWidth = 8
        self.imageView.layer.borderColor = isCorrect ? UIColor.ypGreen.cgColor : UIColor.ypRed.cgColor
        self.imageView.layer.cornerRadius = 20
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)
        {
            [weak self] in
            guard let self = self else { return }
            self.showNextQuestionOrResults()
        }
    }

    // MARK: - Helpers
    private func setAnswerButtonsState(isEnabled: Bool)
    {
        self.yesButton.isEnabled = isEnabled
        self.noButton.isEnabled = isEnabled
    }

    private func imageBorderDefaultStyle()
    {
        self.imageView.layer.masksToBounds = true
        self.imageView.layer.borderWidth = 8
        self.imageView.layer.cornerRadius = 20
        self.imageView.layer.borderColor = UIColor.clear.cgColor
    }

    private func showLoadingIndicator() {
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
    }
    private func hideLoadingIndicator() {
        activityIndicator.isHidden = true
        activityIndicator.stopAnimating()
    }
    private func showNetworkError(message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Попробовать ещё раз", style: .default) { [weak self] _ in
            self?.showLoadingIndicator()
            self?.questionFactory?.loadData()
        })
        present(alert, animated: true)
    }

}


// MARK: - CLASS UI COllor

extension UIColor {
    static var ypBlack: UIColor { UIColor(named: "YP Black") ?? UIColor(red: 0.102, green: 0.106, blue: 0.133, alpha: 1) }
    static var ypWhite: UIColor { UIColor(named: "YP White") ?? UIColor(red: 1, green: 1, blue: 1, alpha: 1) }
    static var ypGreen: UIColor { UIColor(named: "YP Green") ?? UIColor(red: 0.376, green: 0.761, blue: 0.557, alpha: 1) }
    static var ypRed: UIColor { UIColor(named: "YP Red") ?? UIColor(red: 0.961, green: 0.42, blue: 0.34, alpha: 1) }
    static var ypGray: UIColor { UIColor(named: "YP Gray") ?? UIColor(red: 0.26, green: 0.27, blue: 0.133, alpha: 1) }
    static var ypBackground: UIColor { UIColor(named: "YP Background") ?? UIColor(red: 0.102, green: 0.106, blue: 0.133, alpha: 0.6) }
}
